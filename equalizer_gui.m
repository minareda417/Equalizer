function equalizer_gui
fs = 44100;
audioData = randn(1, fs);  % 1-second white noise
filteredAudio = [];  
% create GUI
fig = uifigure('Name', 'Equalizer', 'Position', [100 100 1000 600]);

% Mode dropdown
uilabel(fig, 'Position', [30 550 40 22], 'Text', 'Mode');
modeDD = uidropdown(fig, ...
    'Position', [80 550 100 22], ...
    'Items', {'Standard', 'Custom'}, ...
    'Value', 'Standard', ...
    'ValueChangedFcn', @(dd,event) modeChanged(dd));

% bands table
tbl = uitable(fig, 'Position', [30 210 200 230], ...
    'ColumnName', {'Start (Hz)', 'End (Hz)'}, ...
    'Data', [], 'ColumnEditable', [true true]);
tbl.CellEditCallback = @(src, event) onTableEdit(src, event);
addBandBtn = uibutton(fig, ...
    'Text', 'Add Band', ...
    'Position', [30, 180, 100, 22], ...
    'Visible', 'off',...
    'ButtonPushedFcn', @(btn, event) addCustomBand());

% sampling frequency text box
uilabel(fig, 'Position', [30 500 150 22], 'Text', 'Sampling Frequency');
fsText = uitextarea(fig, 'Position', [200 500 100 22]);
fsBtn = uibutton(fig, ...
    'Text', 'Set Fs', ...
    'Position', [320 500 100 22], ...
    'ButtonPushedFcn', @(btn,event) setFs(fsText));
% buttons
applyBtn = uibutton(fig, 'Text', 'Apply', 'Position', [200 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) applyCallback());
loadBtn = uibutton(fig, 'Text', 'Load Audio', 'Position', [320 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) loadAudioCallback());

% slider panel
sliderPanel = uipanel(fig, 'Position', [320 20 520 420], 'Title', 'Band Gains (dB)');

% play and stop buttons
playBtn = uibutton(fig, 'Text', 'Play', 'Position', [440 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) playCallback());
stopBtn = uibutton(fig, 'Text', 'Stop', 'Position', [560 550 100 22], ...
    'ButtonPushedFcn', @(btn,event) stopCallback());
% reset button
resetBtn = uibutton(fig, ...
    'Text', 'Reset', ...
    'Position', [440 500 100 22], ...
    'ButtonPushedFcn', @(btn,event) resetCallback());


% Initialize with standard bands
updateTableAndSliders();

%% load audio callback
    function loadAudioCallback()
        [file, path] = uigetfile({'*.wav;*.mp3;*.flac', 'Audio Files (*.wav, *.mp3, *.flac)'});
        if isequal(file, 0)
            return;
        end
        [y, f] = audioread(fullfile(path, file));  % Read the audio file
        audioData = y';  % Store audio data
        fs = f;  % Sampling frequency
        uialert(fig, 'Audio loaded successfully!', 'Audio Loaded');
    end

%% apply callback
    function applyCallback()
        bands = tbl.Data;  % get the bands from the table
        if strcmp(modeDD.Value, 'Standard')
        else
            if ~validateBands(bands)
                uialert(fig, 'Custom bands must start at 0 Hz, end at 20 kHz, and be 5–10 continuous bands.', 'Invalid Bands');
                return;
            end
        end

        % fft of the signal
        n = length(audioData);
        signalFreq = fft(audioData);
        freq = (0:n-1) * fs / n;

        % initialize gain to one
        gain = ones(size(signalFreq));

        % apply gain in each band to the mask
        for i = 1:size(bands, 1)
            f1 = bands(i, 1);
            f2 = bands(i, 2);

            gain_dB = getSliderGain(i);            
            gain_lin = 10^(gain_dB / 20);           

            mask = (freq >= f1 & freq <= f2);     
            gain(mask) = gain(mask) * gain_lin;     
        end
        filteredFreq = signalFreq .* gain;
        filteredAudio = real(ifft(filteredFreq));

        uialert(fig, 'Filtered audio ready. Press Play to hear it!', 'Audio Filtered');
        figure;
        t = (0:length(audioData)-1)/fs; 
        plot(t, filteredAudio, 'r', 'DisplayName', 'Filtered Signal'); hold on;
        plot(t, audioData, 'b', 'DisplayName', 'Original Signal');
        title('Original vs Filtered Signal (Time Domain)');
        xlabel('Time (s)');
        ylabel('Amplitude');
        legend;
        grid on;

        ylabel('Amplitude');

    end

%% callback to play
    function playCallback()
        if isempty(filteredAudio)
            uialert(fig, 'No filtered audio to play. Please apply filters first.', 'Error');
            sound(audioData,fs);
        else
            sound(filteredAudio, fs);  % play the filtered audio
            disp('Playing filtered audio.');
        end
    end

%% callback to stop
    function stopCallback()
        clear sound;  % stop audio 
        disp('Audio stopped.');
    end

%% helper function to update table and sliders based on mode
    function updateTableAndSliders()
        if strcmp(modeDD.Value, 'Standard')
            % standard bands
            tbl.Data = [0 200; 200 500; 500 800; 800 1200; 1200 3000; ...
                3000 6000; 6000 12000; 12000 16000; 16000 20000];
            addBandBtn.Visible = 'off';
        else

            % initialize if empty or less than 5 rows
            if isempty(tbl.Data) || size(tbl.Data, 1) < 5
                tbl.Data = zeros(5, 2);
            end
            addBandBtn.Visible = 'on';
        end

        % clear previous sliders
        delete(findall(sliderPanel, 'Type', 'uislider'));
        delete(findall(sliderPanel, 'Type', 'uilabel'));

        % sliders for each frequency band
        numBands = size(tbl.Data, 1);
        sliderWidth = 300;
        sliderSpacing = 40;
        topY = 360; 
        labelOffsetY = -8;  

        for i = 1:numBands
            bandStart = tbl.Data(i, 1);
            bandEnd = tbl.Data(i, 2);
            bandLabel = sprintf('%d–%d Hz', bandStart, bandEnd);

          
            yPos = topY - (i - 1) * sliderSpacing;

            
            uilabel(sliderPanel, ...
                'Position', [30, yPos + labelOffsetY, 100, 22], ...
                'Text', bandLabel);

            uislider(sliderPanel, ...
                'Position', [150, yPos, sliderWidth, 3], ...
                'Limits', [-12 12], ...
                'Value', 0, ...
                'Tag', ['GainSlider' num2str(i)]);
        end

    end

%% helper function to get gain from the slider
    function gain_dB = getSliderGain(bandIndex)
        slider = findall(sliderPanel, 'Tag', ['GainSlider' num2str(bandIndex)]);
        gain_dB = slider.Value;  
    end
%% helper function to add custom bands
    function addCustomBand()
        currentData = tbl.Data;
        numRows = size(currentData, 1);

        if numRows < 10
            if numRows == 0
                newRow = [0 0];
            else
                newRow = [currentData(end, 2) 0];  % start from last end
            end

            tbl.Data = [currentData; newRow];  % append new row
            updateTableAndSliders();           % refresh sliders
        else
            uialert(fig, 'Maximum of 10 bands allowed.', 'Limit Reached');
        end
    end


%% helper function to validate custom bands
    function isValid = validateBands(b)
        isValid = true;
        if size(b, 1) < 5 || size(b, 1) > 10 || b(1, 1) ~= 0 || b(end, 2) ~= 20000
            isValid = false; return;
        end
        for i = 2:size(b, 1)
            if b(i, 1) ~= b(i - 1, 2)
                isValid = false; return;
            end
        end
    end
%% helper function to handle change of mode
    function modeChanged(dd)
        if strcmp(dd.Value, 'Custom')
            tbl.Data = zeros(5, 2);  % clear table data on switch to custom mode
            addBandBtn.Visible = 'on';
        else
            addBandBtn.Visible = 'off';
        end
        updateTableAndSliders();
    end
%% helper function to update table edit
    function onTableEdit(src, event)
        updateTableAndSliders();
    end
%% set sampling frequency callback
    function setFs(fsText)
        valStr = fsText.Value;
        valNum = str2double(valStr);
        if isnan(valNum) || valNum <= 0
            uialert(fsText.Parent, 'Please enter a valid positive number for sampling frequency.', 'Invalid Input');
        else
            fs = valNum;
            disp(['Sampling frequency set to: ' num2str(fs) ' Hz']);
        end
    end
%% reset callback
    function resetCallback()
        % reset mode to 'Standard'
        modeDD.Value = 'Standard';

        % reset table data to default standard bands
        tbl.Data = [0 200; 200 500; 500 800; 800 1200; 1200 3000; ...
            3000 6000; 6000 12000; 12000 16000; 16000 20000];

        updateTableAndSliders();
    end


end
