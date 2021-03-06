function varargout = MESS(varargin)
    
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
        'gui_Singleton',  gui_Singleton, ...
        'gui_OpeningFcn', @MESS_OpeningFcn, ...
        'gui_OutputFcn',  @MESS_OutputFcn, ...
        'gui_LayoutFcn',  [] , ...
        'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    
function MESS_OpeningFcn(hObject, ~, handles, varargin)
    handles.tgroup = uitabgroup('Parent', handles.SATInitializationPanel,'TabLocation', 'top');
    handles.RVCOE  = uitab('Parent', handles.tgroup, 'Title', 'R and V');
    handles.COERV  = uitab('Parent', handles.tgroup, 'Title', 'Orbit Design','Units','normalized');
    handles.RTRT   = uitab('Parent', handles.tgroup, 'Title', 'Two Positions Observation ');
    set(handles.InitialConditions,'Parent',handles.RVCOE);
    set(handles.AddSAT,'Parent',handles.RVCOE);
    set(handles.SATName,'Parent',handles.RVCOE);
    set(handles.SAT_Name,'Parent',handles.RVCOE);
    set(handles.OrbitDesignPanel,'Parent',handles.COERV);
    set(handles.SATList,'String',{'Empty'})
    cla(handles.Space3DScene,'reset');
    cla(handles.GroundTrack,'reset');
    handles.output          = hObject;
    handles.MaxSatNum       =  3;
    handles.Satellites      = [];
    handles.f               = 0;
    handles.SATTrajectories = [];
    handles.GroundTracks    = [];
    handles.Orbits          = [];
    handles.GST             = 0;
    handles.FOV             = [];
    handles.Pairs           = [];
    handles.T0              = juliandate(datetime)*24*3600;
    handles.T               = handles.T0;
    handles.Index           = get(handles.SATList,'Value');
    handles.Earth           = earth_sphere(handles.Space3DScene);
    rotate(handles.Earth,[0 0 1],180,[0 0 0]);
    i = imread('1.jpg');
    imagesc(handles.GroundTrack,[0 360],[-90 90],i);
    axis(handles.GroundTrack,'manual','tight',[0 360 -90 90]),hold on;
    SetProperties(handles.Space3DScene);
    guidata(hObject, handles);
    
function varargout = MESS_OutputFcn(~, ~, handles)
    
    varargout{1} = handles.output;
    varargout{2} = handles;
    
function Save_Callback(hObject, ~, handles)
    X = handles.Satellites;
%     handles.f = handles.f + 1;
%     Name = sprintf('Scenario3%i.mat',handles.f)
    save Scenario.mat X;
    guidata(hObject,handles);
    
function Load_Callback(hObject, eventdata, handles)
    directory = uigetfile;
    X = load(directory); X = struct2cell(X);
    handles.Satellites = cell2ObjArray(X);
    for o = 1:length(handles.Satellites)
            AddtoListbox(handles.SATList,handles.Satellites(o).Name);
            handles.SATTrajectories = [handles.SATTrajectories; animatedline(handles.Space3DScene,'MaximumNumPoints',1,'Marker',randomizeMarker(o),'Color',randomizeColor(o))];
            handles.GroundTracks = [handles.GroundTracks animatedline(handles.GroundTrack,'MaximumNumPoints',180,'Marker',randomizeMarker(o),'Color',randomizeColor(o))];
            handles.Orbits= [handles.Orbits;drawOrbit(handles.Satellites(o),handles.Space3DScene)];
            handles.Pairs = pairSats(length(handles.Satellites));
    end
    guidata(hObject,handles);
    
function Exit_Callback(hObject, ~, handles)
    close(gcf)
    
function Reset_Callback(hObject, ~, handles)
    
    handles.Satellites = [];
    handles.Index = [];
    set(handles.SATList,'String',{'Empty'},'Enable','Off')
    cla(handles.Space3DScene);
    handles.Earth           = earth_sphere(handles.Space3DScene);
    rotate(handles.Earth,[0 0 1],180,[0 0 0]);
    cla(handles.GroundTrack,'reset');
    i = imread('1.jpg');
    imagesc(handles.GroundTrack,[0 360],[-90 90],i);
    axis(handles.GroundTrack,'manual','tight',[0 360 -90 90]),hold on;
    SetProperties(handles.Space3DScene)
    guidata(hObject,handles)
    

function Simulate_Callback(hObject, ~, handles)
    Lines= [];
    if ~isempty(handles.Satellites)
        while true
            if get(hObject,'Value')==0
                break;
            end
            handles.GST = calculateGST(handles.GST);
            for o = 1:length(handles.Satellites)
                handles.Satellites(o) = handles.Satellites(o).update(handles.T,handles.GST);
                addpoints(handles.SATTrajectories(o),handles.Satellites(o).States.R(1),handles.Satellites(o).States.R(2),handles.Satellites(o).States.R(3))
                addpoints(handles.GroundTracks(o),handles.Satellites(o).States.Longitude,handles.Satellites(o).States.Lattitude);
%                 S = drawFOV(handles.Satellites(handles.Index),handles.Space3DScene,handles.GST);
                SetProperties(handles.Space3DScene);          
                drawnow;
            end
            handles.Index = get(handles.SATList,'Value');
            rotate(handles.Earth,[0 0 1],OmegaEarth*60*10*180/pi,[0 0 0]);
            Lines = [Lines;drawLoS(handles.Satellites,handles.Pairs,handles.Space3DScene)];
            UpdateSatState(handles.Satellites(handles.Index),handles);
            handles.T = handles.T + 60*10;
            guidata(hObject,handles);
            drawnow
%             delete(Lines);
        end
    end
    guidata(hObject,handles)
    
    
function RemoveSAT_Callback(hObject, ~, handles)
    
    if isempty(handles.Satellites) && isempty(get(handles.SATList,'String'))
        set(handles.SATList,'String',{'Empty'},'Enable','off');
    elseif isempty(handles.Satellites)
        set(handles.SATList,'String',{'Empty'},'Enable','off');
    elseif isempty(get(handles.SATList,'String')) && ~isempty(handles.Satellites)
        for o = 1:length(handles.Satellites)
            AddtoListbox(handles.SATList,handles.Satellites(o).Name);
        end
    else
        index = get(handles.SATList,'Value');
        if (index > 0)
            handles.Satellites(index) = [];
            clearpoints(handles.Orbits(index));
            clearpoints(handles.SATTrajectories(index));
            clearpoints(handles.GroundTracks(index));
            handles.Orbits(index) = [];
            handles.SATTrajectories(index) = [];
            handles.GroundTracks(index) = [];
            RemovefromListbox(handles.SATList,index,length(handles.Satellites));
        end
    end
    handles.Pairs = pairSats(length(handles.Satellites));
    guidata(hObject,handles);

function Rotate_Callback(hObject, eventdata, handles)
    set(handles.Zoom,'Value',0);
    x = rotate3d(handles.Space3DScene); x.Enable = 'on';

function Zoom_Callback(hObject, eventdata, handles)
    set(handles.Rotate,'Value',0);
    zoom(handles.Space3DScene);

function SATList_Callback(hObject, ~, handles)
    
    handles.Index = get(hObject,'Value');
    UpdateOrbitInfo(handles.Satellites(handles.Index),handles);
    UpdateSatState(handles.Satellites(handles.Index),handles);
    guidata(hObject,handles);
    
function DestinationMajorAxis_Callback(hObject, ~, handles)
    
function TransferTime_Callback(hObject, ~, handles)
    
function DestinationEccentricity_Callback(hObject, ~, handles)
    
function Transfer_Callback(hObject, ~, handles)
    
function AddSAT_Callback(hObject, ~, handles)
    % Initialization Data from Initial Conditions Panel
    R0                 = [str2double(get(handles.Rx,'String'));str2double(get(handles.Ry,'String'));str2double(get(handles.Rz,'String'))];
    V0                 = [str2double(get(handles.Vx,'String'));str2double(get(handles.Vy,'String'));str2double(get(handles.Vz,'String'))];
    Date               = get(handles.t0,'String');    t = datetime(Date,'InputFormat','dd-MMM-yyyy HH:mm:ss');    T0 = juliandate(t)*24*3600;
    Name               = get(handles.SATName,'String');
    handles.Satellites = [handles.Satellites Satellite];
    handles.Index      = length(handles.Satellites);
    handles.SATTrajectories = [handles.SATTrajectories; animatedline(handles.Space3DScene,'MaximumNumPoints',1,'Marker',randomizeMarker(handles.Index),'Color',randomizeColor(handles.Index))];
    handles.GroundTracks = [handles.GroundTracks animatedline(handles.GroundTrack,'MaximumNumPoints',180,'Marker',randomizeMarker(handles.Index),'Color',randomizeColor(handles.Index))];
    handles.Satellites(handles.Index).RVCOE(R0,V0,T0,Name); 
    UpdateOrbitInfo(handles.Satellites(handles.Index),handles);
    AddtoListbox(handles.SATList,handles.Satellites(handles.Index).Name);
    set(handles.SATList,'value',handles.Index)
    handles.Orbits= [handles.Orbits;drawOrbit(handles.Satellites(handles.Index),handles.Space3DScene)];
    handles.Pairs = pairSats(length(handles.Satellites));
    guidata(hObject,handles);

function PlaceOrbit_Callback(hObject, eventdata, handles)
    a   = str2double(get(handles.ODa,'String'));
    AoA = str2double(get(handles.ODAoA,'String'));
    AoP = str2double(get(handles.ODAoP,'String'));
    e   = str2double(get(handles.ODe,'String'));
    i   = str2double(get(handles.ODi,'String'));
    nu  = str2double(get(handles.ODnu,'String'));
    Name = get(handles.ODName,'String');
    Date = get(handles.ODTime,'String');    t = datetime(Date,'InputFormat','dd-MMM-yyyy HH:mm:ss');    T0 = juliandate(t)*24*3600;
    handles.Satellites = [handles.Satellites Satellite]; 
    handles.Index      = length(handles.Satellites);
    if isempty(Name)
        Name = sprintf('Untitled Sat %d',handles.Index);
    end
    
    handles.SATTrajectories = [handles.SATTrajectories; animatedline(handles.Space3DScene,'MaximumNumPoints',1,'Marker',randomizeMarker(handles.Index),'Color',randomizeColor(handles.Index))];
    handles.GroundTracks = [handles.GroundTracks animatedline(handles.GroundTrack,'MaximumNumPoints',180,'Marker',randomizeMarker(handles.Index),'Color',randomizeColor(handles.Index))];
    handles.Satellites(handles.Index).COERV(AoA,i,AoP,nu,e,a,T0,Name)
    UpdateOrbitInfo(handles.Satellites(handles.Index),handles);
    AddtoListbox(handles.SATList,handles.Satellites(handles.Index).Name);
    set(handles.SATList,'value',handles.Index)
    handles.Orbits= [handles.Orbits;drawOrbit(handles.Satellites(handles.Index),handles.Space3DScene)];
    handles.Pairs = pairSats(length(handles.Satellites));
    guidata(hObject,handles);

function Rx_Callback(hObject, ~, handles)
    
function Ry_Callback(hObject, ~, handles)
    
function Rz_Callback(hObject, ~, handles)
    
function Vx_Callback(hObject, ~, handles)
    
function Vy_Callback(hObject, ~, handles)
    
function Vz_Callback(hObject, ~, handles)
    
function t0_Callback(hObject, ~, handles)
    
function SATName_Callback(hObject, ~, handles)
    
function SpaceSim_Callback(hObject, ~, handles)
    [~,h] = SPACE;
    handles.Surprise = h;
    set(handles.Space3DScene,'Parent',handles.Surprise.Surprise);
    
    %%
function SATList_CreateFcn(hObject, ~, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function DestinationMajorAxis_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function TransferTime_CreateFcn(hObject, ~, handles)
    % hObject    handle to TransferTime (see GCBO)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function DestinationEccentricity_CreateFcn(hObject, ~, handles)
    % hObject    handle to DestinationEccentricity (see GCBO)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Rx_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Ry_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Rz_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Vx_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Vy_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function Vz_CreateFcn(hObject, ~, handles)
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function t0_CreateFcn(hObject, ~, handles)
    
    
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
function SATName_CreateFcn(hObject, ~, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end



function ODa_Callback(hObject, eventdata, handles)
% hObject    handle to ODa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODa as text
%        str2double(get(hObject,'String')) returns contents of ODa as a double


% --- Executes during object creation, after setting all properties.
function ODa_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODe_Callback(hObject, eventdata, handles)
% hObject    handle to ODe (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODe as text
%        str2double(get(hObject,'String')) returns contents of ODe as a double


% --- Executes during object creation, after setting all properties.
function ODe_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODe (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODAoA_Callback(hObject, eventdata, handles)
% hObject    handle to ODAoA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODAoA as text
%        str2double(get(hObject,'String')) returns contents of ODAoA as a double


% --- Executes during object creation, after setting all properties.
function ODAoA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODAoA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODAoP_Callback(hObject, eventdata, handles)
% hObject    handle to ODAoP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODAoP as text
%        str2double(get(hObject,'String')) returns contents of ODAoP as a double


% --- Executes during object creation, after setting all properties.
function ODAoP_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODAoP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODi_Callback(hObject, eventdata, handles)
% hObject    handle to ODi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODi as text
%        str2double(get(hObject,'String')) returns contents of ODi as a double


% --- Executes during object creation, after setting all properties.
function ODi_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODnu_Callback(hObject, eventdata, handles)
% hObject    handle to ODnu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODnu as text
%        str2double(get(hObject,'String')) returns contents of ODnu as a double


% --- Executes during object creation, after setting all properties.
function ODnu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODnu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function ODTime_Callback(hObject, eventdata, handles)
% hObject    handle to ODTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODTime as text
%        str2double(get(hObject,'String')) returns contents of ODTime as a double


% --- Executes during object creation, after setting all properties.
function ODTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ODName_Callback(hObject, eventdata, handles)
% hObject    handle to ODName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ODName as text
%        str2double(get(hObject,'String')) returns contents of ODName as a double


% --- Executes during object creation, after setting all properties.
function ODName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ODName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Load.

% hObject    handle to Load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
