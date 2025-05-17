% automate_equalizer.m
% Script to automate sample runs for equalizer GUI functionality:
% - Apply FIR (Hamming, Hanning, Blackman) and IIR (Butterworth, Cheby1, Cheby2) filters
% - Change sample rates (×4 and ÷2)
% - Plot signals in time and frequency domains exactly like GUI
% - Save outputs and figures for inclusion in reports

%% User input: audio file path
userPath = input('Enter path to WAV file (empty = white noise): ', 's');
if ~isempty(userPath) && exist(userPath, 'file')
    [ytemp, fs_orig] = audioread(userPath);
    if size(ytemp,2)>1, ymono = mean(ytemp,2); else ymono=ytemp; end
    audioData = ymono'; sourceLabel = userPath;
    fprintf('Loaded audio: %s at Fs=%d Hz\n',userPath,fs_orig);
else
    fs_orig=44100; audioData=randn(1,fs_orig); sourceLabel='white noise';
    fprintf('Using white noise at default Fs=%d Hz\n',fs_orig);
end

outputDir = 'results'; if ~exist(outputDir,'dir'), mkdir(outputDir); end

% Configurations
tableBands = [0 200;200 500;500 800;800 1200;1200 3000;3000 6000;6000 12000;12000 16000;16000 20000];
firOrder=64; iirOrder=8; cheby1_Rp=1; cheby2_Rs=30;
resampleConfigs = {'orig',1;'up4',4;'down2',0.5};

% Filter definitions
filters = {
    struct('type','FIR','param','Hamming');
    struct('type','FIR','param','Hanning');
    struct('type','FIR','param','Blackman');
    struct('type','IIR','param','Butterworth');
    struct('type','IIR','param','Cheby1');
    struct('type','IIR','param','Cheby2');
};

for r=1:size(resampleConfigs,1)
    rsName = resampleConfigs{r,1}; rsFactor=resampleConfigs{r,2};
    fs = round(fs_orig*rsFactor);
    if rsFactor~=1, y = resample(audioData,fs,fs_orig);
    else y=audioData; end

    for fi=1:numel(filters)
        fDef = filters{fi};
        scenedir = fullfile(outputDir, sprintf('%s_%s_%s', fDef.type, fDef.param, rsName));
        if ~exist(scenedir,'dir'), mkdir(scenedir); end
        
        for b=1:size(tableBands,1)
            f1=tableBands(b,1); f2=tableBands(b,2);
            Nyq=fs/2;
            f1=min(max(f1,eps),Nyq-eps); f2=min(max(f2,eps),Nyq-eps);
            if f1>=f2, f1=eps; f2=Nyq-eps; end
            Wn=sort([f1 f2])/Nyq; Wn=min(max(Wn,eps),1-eps);

            % Design
            switch fDef.type
                case 'FIR'
                    switch fDef.param
                        case 'Hamming', win=hamming(firOrder+1);
                        case 'Hanning', win=hanning(firOrder+1);
                        case 'Blackman', win=blackman(firOrder+1);
                    end
                    [bcoef,acoef]=fir1(firOrder,Wn,win);
                case 'IIR'
                    switch fDef.param
                        case 'Butterworth'
                            [bcoef,acoef]=butter(iirOrder,Wn);
                        case 'Cheby1'
                            [bcoef,acoef]=cheby1(iirOrder,cheby1_Rp,Wn);
                        case 'Cheby2'
                            [bcoef,acoef]=cheby2(iirOrder,cheby2_Rs,Wn);
                    end
            end
            % Filter
            y_filt=filter(bcoef,acoef,y);
            y_filt=y_filt/max(abs(y_filt));
            L=min(numel(y),numel(y_filt)); y_tr=y(1:L); y_ff=y_filt(1:L);

            % Save audio
            outFile=fullfile(scenedir,sprintf('band_%d_%dHz.wav',round(f1),round(f2)));
            audiowrite(outFile,y_ff(:),fs);

            % Plot GUI-style
            fig=figure('Visible','off','Name',sprintf('%s %s %d-%d Hz (%s)',fDef.type,fDef.param,round(f1),round(f2),rsName));
            % 1 Time
            subplot(2,3,1); t=(0:L-1)/fs;
            plot(t,y_ff,'r',t,y_tr,'b'); legend('Filtered','Original'); grid on;
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

            saveas(fig,fullfile(scenedir,sprintf('analysis_%s_%s_%d_%d.png',rsName,fDef.param,round(f1),round(f2)))); close(fig);
        end
    end
end

fprintf('\nDone. Results in "%s".\n',outputDir);
