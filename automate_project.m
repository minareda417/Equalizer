% automate_equalizer.m
% Script to automate sample runs for equalizer GUI functionality:
% - Apply FIR and IIR filters to white noise or user-specified audio
% - Change sample rates (×4 and ÷2)
% - Plot signals in time and frequency domains exactly like GUI
% - Save outputs and figures for inclusion in reports

%% User input: audio file path
userPath = input('Enter path to WAV file (empty = white noise): ', 's');
if ~isempty(userPath) && exist(userPath, 'file')
    [ytemp, fs_orig] = audioread(userPath);
    if size(ytemp,2) > 1, ymono = mean(ytemp,2); else ymono = ytemp; end
    audioData = ymono';  % row vector
    sourceLabel = userPath;
    fprintf("Loaded audio: %s at Fs=%d Hz", userPath, fs_orig);
else
    fs_orig = 44100;
    audioData = randn(1, fs_orig);
    sourceLabel = 'white noise';
    fprintf('Using white noise at default Fs=%d Hz', fs_orig);
end

outputDir = 'results'; if ~exist(outputDir,'dir'), mkdir(outputDir); end

tableBands = [0 200;200 500;500 800;800 1200;1200 3000;3000 6000;6000 12000;12000 16000;16000 20000];
firOrder = 64; iirOrder = 8;
resampleConfigs = {'orig',1;'up4',4;'down2',0.5}; filterTypes = {'FIR','IIR'};

for fidx=1:numel(filterTypes)
    fType = filterTypes{fidx}; fprintf('\nProcessing %s filters...\n',fType);
    for r=1:size(resampleConfigs,1)
        rsName = resampleConfigs{r,1}; rsFactor = resampleConfigs{r,2};
        fs = round(fs_orig * rsFactor);
        if rsFactor~=1, y = resample(audioData,fs,fs_orig); else y=audioData; end
        scenedir = fullfile(outputDir, sprintf('%s_%s',fType,rsName));
        if ~exist(scenedir,'dir'), mkdir(scenedir); end
        
        for b=1:size(tableBands,1)
            f1=tableBands(b,1); f2=tableBands(b,2);
            Nyq=fs/2;
            f1=min(max(f1,eps),Nyq-eps); f2=min(max(f2,eps),Nyq-eps);
            if f1>=f2, f1=eps; f2=Nyq-eps; end
            Wn = sort([f1 f2])/Nyq; Wn = min(max(Wn,eps),1-eps);
            switch fType
                case 'FIR', win=hamming(firOrder+1); [bcoef,acoef]=fir1(firOrder,Wn,win);
                case 'IIR', [bcoef,acoef]=butter(iirOrder,Wn);
            end
            y_filt = filter(bcoef,acoef,y);
            % normalize and match lengths
            y_filt = y_filt / max(abs(y_filt));
            L = min(length(y), length(y_filt));
            y_trunc = y(1:L); yf_trunc = y_filt(1:L);
            % save audio column vector
            audiowrite(fullfile(scenedir,sprintf('band_%d_%dHz.wav',round(f1),round(f2))), yf_trunc(:), fs);
            % analysis plot
            fig=figure('Visible','off');
            % 1 Time
            subplot(2,3,1); t=(0:L-1)/fs;
            plot(t,yf_trunc,'r',t,y_trunc,'b'); legend('Filtered','Original'); grid on;
            title('Time Domain'); xlabel('Time (s)'); ylabel('Amplitude');
            % 2 Mag
            subplot(2,3,2); [H,fA]=freqz(bcoef,acoef,1024,fs);
            plot(fA,20*log10(abs(H)),'LineWidth',1.2); grid on;
            title('Frequency Response (Magnitude)'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
            % 3 Phase
            subplot(2,3,3); plot(fA,angle(H)*180/pi,'LineWidth',1.2); grid on;
            title('Phase Response (Wrapped)'); xlabel('Frequency (Hz)'); ylabel('Phase (°)');
            % 4 Impulse
            subplot(2,3,4); imp=filter(bcoef,acoef,[1;zeros(99,1)]);
            stem(0:99,imp,'filled'); grid on;
            title('Impulse Response'); xlabel('Samples'); ylabel('Amplitude');
            % 5 Step
            subplot(2,3,5); stepR=filter(bcoef,acoef,ones(100,1));
            plot(0:99,stepR,'LineWidth',1.2); grid on;
            title('Step Response'); xlabel('Samples'); ylabel('Amplitude');
            % 6 Pole-Zero
            subplot(2,3,6); zplane(bcoef,acoef); grid on;
            title('Poles and Zeros');
            saveas(fig,fullfile(scenedir,sprintf('analysis_%s_%d_%d.png',rsName,round(f1),round(f2)))); close(fig);
        end
    end
end
fprintf('\nDone. Results in "%s".\n',outputDir);
