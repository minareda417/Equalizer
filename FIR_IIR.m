t = linspace(0, 10*pi, 1000);
sin_wave = sin(t);

n = input("Enter n: ");
fc = input("Enter Fc: ");

impulse_respone = input("Choose Impulse respone:\n 1. FIR\n 2. IIR\n");

switch impulse_respone

    case 1
        window = input("Choose Window:\n 1. Hamming\n 2. Hanning\n 3.Blackman\n");
        
        switch window
            case 1
                b = fir1(n, fc, hamming(n+1));
                l = "Hamming";
            case 2
                b = fir1(n, fc, hanning(n+1));
                l = "Hanning";
            case 3
                b = fir1(n, fc, blackman(n+1));
                l = "Blackman";
            otherwise
                disp("Invalid input.\n");
        end
        
        y = filter(b, 1, sin_wave);
        
        figure;
        plot(t, y, 'r', 'LineWidth', 1.2);
        legend(l);
        xlabel('Time');
        ylabel('Amplitude');
        title('Sine Wave Filtered');
        grid on;

    case 2
        filter_order = input("Choose filter:\n 1.Butterworth\n 2.Chebychev I\n 3.Chebychev II\n");
        
        switch filter_order
            case 1
                [b, a] = butter(n, fc);
                l = "Butterworth";
            case 2
                rp = input("Enter Rp: ");
                [b, a] = cheby1(n, rp, fc);
                l = "Chebychev I";
            case 3
                rs = input("Enter Rs: ");
                [b, a] = cheby2(n, rs, fc);
                l = "Chebychev II";
            otherwise
                disp("Invalid input\n");
        end


        y = filter(b, a, sin_wave);

        figure;
        plot(t, y, 'r', 'LineWidth', 1.2);
        legend(l);
        xlabel('Time');
        ylabel('Amplitude');
        title('Sine Wave Filtered');
        grid on;

    otherwise
        disp("Invalid input\n");
end
