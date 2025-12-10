%% TNA - SÉANCE 1 : ANALYSE PDM
clear; close all; clc;

%% CHARGEMENT
if exist('pdm_in.mat', 'file')
    load('pdm_in.mat');
end
signal_pdm = in;

Fs_in = 6.144e6;  % Fréquence d'échantillonnage PDM (6.144 MHz)

%% 2. ANALYSE TEMPORELLE

N_total = 1000;
t_total = (0:N_total-1)/Fs_in;

figure('Name', 'Analyse Signal PDM', 'Color', 'w');
subplot(3,1,1);
stairs(t_total, signal_pdm(1:N_total), 'LineWidth', 1.5);
title('Signal PDM (Domaine Temporel - Total)');
xlabel('Temps (s)');
ylabel('Amplitude');
grid on;

%% ANALYSE FRÉQUENTIELLE

N_fft = 2^nextpow2(length(signal_pdm)); % Taille FFT
Y = fft(signal_pdm - mean(signal_pdm), N_fft); % FFT du signal décalé
P2 = abs(Y/length(signal_pdm));
P1 = P2(1:N_fft/2+1); 
P1(2:end-1) = 2*P1(2:end-1); 

f_fft = Fs_in*(0:(N_fft/2))/N_fft;

subplot(3,1,2);
semilogx(f_fft, 20*log10(P1), 'LineWidth', 1.2);
title('Signal PDM (Domaine Fréquentiel - Log)');
xlabel('Fréquence (Hz)');
ylabel('Magnitude (dB)');
grid on;
xlim([10 Fs_in/2]); % Start at 10 Hz

%% 4. ANALYSE FRÉQUENTIELLE (Echelle Linéaire)

subplot(3,1,3);
plot(f_fft, 20*log10(P1), 'LineWidth', 1.2);
title('Signal PDM (Domaine Fréquentiel - Linéaire)');
xlabel('Fréquence (Hz)');
ylabel('Magnitude (dB)');
grid on;
xlim([1 Fs_in/2]);
