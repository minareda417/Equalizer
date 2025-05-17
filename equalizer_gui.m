function equalizer_gui
fs = 44100;
audioData = randn(1, fs);  % 1-second white noise
filteredAudio = [];

% create GUI
fig = uifigure('Name', 'Equalizer', 'Position', [100 100 1100 600]);

% Mode dropdown
uilabel(fig, 'Position', [30 550 40 22], 'Text', 'Mode');
modeDD = uidropdown(fig, ...
    'Position', [80 550 100 22], ...
    'Items', {'Standard', 'Custom'}, ...
    'Value', 'Standard', ...
    'ValueChangedFcn', @(dd,event) modeChanged(dd));

% Filter type dropdown
uilabel(fig, 'Position', [200 550 60 22], 'Text', 'Filter Type');
filterTypeDD = uidropdown(fig, ...
    'Position', [270 550 100 22], ...
    'Items', {'FIR', 'IIR'}, ...
    'Value', 'FIR', ...
    'ValueChangedFcn', @(dd,event) filterTypeChanged(dd));

% FIR window dropdown (tagged)
uilabel(fig, 'Position', [390 550 60 22], 'Text', 'Window', 'Visible','on', 'Tag','windowLabel');
windowDD = uidropdown(fig, ...
    'Position', [450 550 100 22], ...
    'Items', {'Hamming', 'Hanning', 'Blackman'}, ...
    'Value', 'Hamming', ...
    'Visible', 'on', ...
    'Tag','windowDD');

% IIR type dropdown (hidden initially)
uilabel(fig, 'Position', [390 550 60 22], 'Text', 'IIR Type', 'Visible','off','Tag','iirLabel');
iirTypeDD = uidropdown(fig, ...
    'Position', [450 550 120 22], ...
    'Items', {'Butterworth', 'Chebychev I', 'Chebychev II'}, ...
    'Value', 'Butterworth', ...
    'Visible', 'off', ...
    'Tag','iirDD', ...
    'ValueChangedFcn', @(dd,event) iirTypeChanged(dd));

% Chebychev parameters
uilabel(fig, 'Position', [580 550 30 22], 'Text', 'Rp', 'Visible','off','Tag','rpLabel');
rpText = uitextarea(fig, 'Position', [610 550 50 22], 'Visible','off','Tag','rpText');
uilabel(fig, 'Position', [580 550 30 22], 'Text', 'Rs', 'Visible','off','Tag','rsLabel');
rsText = uitextarea(fig, 'Position', [610 550 50 22], 'Visible','off','Tag','rsText');

% Filter order input
uilabel(fig, 'Position', [700 550 60 22], 'Text', 'Order', 'Visible','on');
orderText = uitextarea(fig, 'Position', [760 550 50 22], 'Value','64');

% bands table
tbl = uitable(fig, 'Position', [30 210 250 230], ...
    'ColumnName', {'Start (Hz)', 'End (Hz)'}, ...
    'Data', [], 'ColumnEditable', [true true]);
tbl.CellEditCallback = @(src, event) onTableEdit(src, event);
addBandBtn = uibutton(fig, ...
    'Text', 'Add Band', ...
    'Position', [30, 180, 100, 22], ...
    'Visible', 'off',...
    'ButtonPushedFcn', @(btn, event) addCustomBand());

% sampling frequency text box
fsDisplayLabel = uilabel(fig, 'Position', [30 500 150 22], 'Text', ['Current fs: ' num2str(fs) ' Hz']);
fsText = uitextarea(fig, 'Position', [200 500 100 22]);
fsBtn = uibutton(fig, ...
    'Text', 'Set Fs', ...
    'Position', [320 500 100 22], ...
    'ButtonPushedFcn', @(btn,event) setFs(fsText));

% playback and control buttons
yPosCtrl = 500; % y-position for play/stop/reset
playBtn = uibutton(fig, 'Text', 'Play', 'Position', [440 yPosCtrl 100 22], ...
    'ButtonPushedFcn', @(btn,event) playCallback());
stopBtn = uibutton(fig, 'Text', 'Stop', 'Position', [560 yPosCtrl 100 22], ...
    'ButtonPushedFcn', @(btn,event) stopCallback());
resetBtn = uibutton(fig, ...
    'Text', 'Reset', ...
    'Position', [680 yPosCtrl 100 22], ...
    'ButtonPushedFcn', @(btn,event) resetCallback());

% Apply and Load buttons
applyBtn = uibutton(fig, 'Text', 'Apply', 'Position', [830 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) applyCallback());
loadBtn = uibutton(fig, 'Text', 'Load Audio', 'Position', [940 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) loadAudioCallback());

% slider panel
sliderPanel = uipanel(fig, 'Position', [320 20 760 460], 'Title', 'Band Gains (dB)');

% Initialize with standard bands
updateTableAndSliders();

%% load audio callback
    function loadAudioCallback()
        [file, path] = uigetfile({'*.wav;*.mp3;*.flac', 'Audio Files (*.wav, *.mp3, *.flac)'});
        if isequal(file, 0)
            return;
        end
        [y, f] = audioread(fullfile(path, file));
        audioData = y';
        fs = f;
        uialert(fig, 'Audio loaded successfully!', 'Audio Loaded');
    end
%% apply callback
function applyCallback()
    bands = tbl.Data;
    if strcmp(modeDD.Value, 'Custom') && ~validateBands(bands)
        uialert(fig, 'Custom bands must start at 0 Hz, end at 20 kHz, and be 5–10 continuous bands.', 'Invalid Bands');
        return;
    end

    n = str2double(orderText.Value);
    filteredAudio = zeros(size(audioData));
    scenedir = 'filter_analysis'; 
    if ~exist(scenedir, 'dir')
        mkdir(scenedir);
    end

    for i = 1:size(bands,1)
        f1 = bands(i,1);
        f2 = bands(i,2);
        gain_dB = getSliderGain(i);
        gain_lin = 10^(gain_dB/20);
        epsilon = 1e-6;

        if f1 == 0
            f1 = epsilon * fs/2;
        end
        if f2 >= fs/2
            f2 = (1 - epsilon) * fs/2;
        end

        Wn = [f1 f2]/(fs/2);
        label = filterTypeDD.Value;
        windowLabel = '';
        switch filterTypeDD.Value
            case 'FIR'
                switch windowDD.Value
                    case 'Hamming', win = hamming(n+1); windowLabel = 'Hamming';
                    case 'Hanning', win = hanning(n+1); windowLabel = 'Hanning';
                    case 'Blackman', win = blackman(n+1); windowLabel = 'Blackman';
                end
                b = fir1(n, Wn, win);
                a = 1;
            case 'IIR'
                switch iirTypeDD.Value
                    case 'Butterworth'
                        [b,a] = butter(n, Wn);
                        windowLabel = 'Butterworth';
                    case 'Chebychev I'
                        rp = str2double(rpText.Value);
                        [b,a] = cheby1(n, rp, Wn);
                        windowLabel = 'Cheby I';
                    case 'Chebychev II'
                        rs = str2double(rsText.Value);
                        [b,a] = cheby2(n, rs, Wn);
                        windowLabel = 'Cheby II';
                end
        end

        section = filter(b, a, audioData);
        filteredAudio = filteredAudio + gain_lin * section;

        % save figure
        figPlot = figure('Visible', 'off', 'Name', sprintf('Filter Analysis [%d-%d Hz]', f1, f2), 'NumberTitle', 'off');
        
        % time domain
        subplot(2,3,1);
        t = (0:length(audioData)-1)/fs;
        plot(t, filteredAudio, 'r', t, audioData, 'b');
        title('Time Domain');
        xlabel('Time (s)'); ylabel('Amplitude');
        legend('Filtered', 'Original'); grid on;

        % frequency response
        subplot(2,3,2);
        [H, f_axis] = freqz(b, a, 1024, fs);
        plot(f_axis, 20*log10(abs(H)), 'LineWidth', 1.2);
        title('Frequency Response (Magnitude)');
        xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)'); grid on;

        % phase response
        subplot(2,3,3);
        plot(f_axis, angle(H) * 180/pi, 'LineWidth', 1.2);
        title('Phase Response');
        xlabel('Frequency (Hz)'); ylabel('Phase (°)'); grid on;

        % impulse response
        subplot(2,3,4);
        impulse_response = filter(b, a, [1; zeros(99,1)]);
        stem(0:99, impulse_response, 'filled');
        title('Impulse Response');
        xlabel('Samples'); ylabel('Amplitude'); grid on;

        % step response
        subplot(2,3,5);
        step_response = filter(b, a, ones(100,1));
        plot(0:99, step_response, 'LineWidth', 1.2);
        title('Step Response');
        xlabel('Samples'); ylabel('Amplitude'); grid on;

       % pole zero plot
        subplot(2,3,6);
        zplane(b, a);
        title('Poles and Zeros'); grid on;

        sgtitle(sprintf('Band: %d–%d Hz | Fs = %d Hz | %s %s', round(f1), round(f2), fs, label, windowLabel));
        saveas(figPlot, fullfile(scenedir, sprintf('analysis_%s_%d_%d.png', label, round(f1), round(f2))));
        close(figPlot);
    end

    uialert(fig, 'Filtered audio ready. Press Play to hear it!', 'Audio Filtered');

    audiowrite(fullfile(scenedir, 'filtered_output.wav'), filteredAudio, fs);
end


%% filter type changed
    function filterTypeChanged(dd)
        winLbl    = findobj(fig,'Tag','windowLabel');
        winDD     = findobj(fig,'Tag','windowDD');
        iirLbl    = findobj(fig,'Tag','iirLabel');
        iirDD     = findobj(fig,'Tag','iirDD');
        rpLbl     = findobj(fig,'Tag','rpLabel');
        rpTxt     = findobj(fig,'Tag','rpText');
        rsLbl     = findobj(fig,'Tag','rsLabel');
        rsTxt     = findobj(fig,'Tag','rsText');
        if strcmp(dd.Value,'FIR')
            winLbl.Visible = 'on';
            winDD.Visible  = 'on';
            iirLbl.Visible = 'off';
            iirDD.Visible  = 'off';
            rpLbl.Visible  = 'off';
            rpTxt.Visible  = 'off';
            rsLbl.Visible  = 'off';
            rsTxt.Visible  = 'off';
        else
            winLbl.Visible = 'off';
            winDD.Visible  = 'off';
            iirLbl.Visible = 'on';
            iirDD.Visible  = 'on';
            % update Cheby visibility
            iirTypeChanged(iirDD);
        end
    end

%% IIR type changed
    function iirTypeChanged(dd)
        rpLbl = findobj(fig,'Tag','rpLabel');
        rpTxt = findobj(fig,'Tag','rpText');
        rsLbl = findobj(fig,'Tag','rsLabel');
        rsTxt = findobj(fig,'Tag','rsText');
        rpLbl.Visible = 'off'; rpTxt.Visible = 'off';
        rsLbl.Visible = 'off'; rsTxt.Visible = 'off';
        switch dd.Value
            case 'Chebychev I'
                rpLbl.Visible = 'on'; rpTxt.Visible = 'on';
            case 'Chebychev II'
                rsLbl.Visible = 'on'; rsTxt.Visible = 'on';
        end
    end

%% play callback
    function playCallback()
        if isempty(filteredAudio)
            uialert(fig,'No filtered audio to play. Please apply filters first.','Error');
            sound(audioData,fs);
        else
            sound(filteredAudio,fs);
        end
    end

%% stop callback
    function stopCallback()
        clear sound;
    end

%% update table/sliders
    function updateTableAndSliders()
        if strcmp(modeDD.Value,'Standard')
            tbl.Data = [0 200;200 500;500 800;800 1200;1200 3000;3000 6000;6000 12000;12000 16000;16000 20000];
            addBandBtn.Visible = 'off';
        else
            if isempty(tbl.Data) || size(tbl.Data,1)<5
                tbl.Data = zeros(5,2);
            end
            addBandBtn.Visible = 'on';
        end
        delete(findall(sliderPanel,'Type','uislider'));
        delete(findall(sliderPanel,'Type','uilabel'));
        numBands = size(tbl.Data,1);
        sliderWidth = 300; sliderSpacing = 40; topY = 360; offsetY = -8;
        for i=1:numBands
            lbl = sprintf('%d–%d Hz', tbl.Data(i,1), tbl.Data(i,2));
            y = topY - (i-1)*sliderSpacing;
            uilabel(sliderPanel,'Position',[30,y+offsetY,100,22],'Text',lbl);
            uislider(sliderPanel,'Position',[150,y,sliderWidth,3],'Limits',[-12 12],'Value',0,'Tag',['GainSlider' num2str(i)]);
        end
    end

%% get slider gain
    function g = getSliderGain(idx)
        s = findall(sliderPanel,'Tag',['GainSlider' num2str(idx)]);
        g = s.Value;
    end

%% add custom band
    function addCustomBand()
        data = tbl.Data;
        r = size(data,1);
        if r < 10
            if r == 0
                new = [0 0];
            else
                new = [data(end,2) 0];
            end
            tbl.Data = [data; new];
            updateTableAndSliders();
        else
            uialert(fig,'Maximum of 10 bands allowed.','Limit Reached');
        end
    end

%% validate bands
    function ok = validateBands(b)
        ok = true;
        if size(b,1)<5 || size(b,1)>10 || b(1,1)~=0 || b(end,2)~=20000, ok=false; return; end
        for i=2:size(b,1)
            if b(i,1)~=b(i-1,2), ok=false; return; end
        end
    end

%% mode changed
    function modeChanged(dd)
        if strcmp(dd.Value,'Custom')
            tbl.Data=zeros(5,2);
            addBandBtn.Visible = 'on';
        else
            addBandBtn.Visible = 'off';
        end
        updateTableAndSliders();
    end

%% table edit
    function onTableEdit(~,~)
        updateTableAndSliders();
    end

%% set Fs
    function setFs(txt)
        v = str2double(txt.Value);
        if isnan(v) || v <= 0
            uialert(txt.Parent,'Please enter valid positive Fs.','Invalid Input');
        else
            fs = v;
            fsDisplayLabel.Text = ['Current fs: ' num2str(fs) ' Hz'];
        end
    end

%% reset
    function resetCallback()
        modeDD.Value = 'Standard';
        tbl.Data = [0 200;200 500;500 800;800 1200;1200 3000;3000 6000;6000 12000;12000 16000;16000 20000];
        updateTableAndSliders();
    end
end
