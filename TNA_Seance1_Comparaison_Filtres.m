%% COMPARAISON FILTRES PDM (FIR vs IIR Butterworth vs IIR Cheby1 vs IIR Cheby2)
clear variables; close all; clc;

%% 1. CHARGEMENT
fprintf('Chargement des données...\n');
load('pdm_in.mat');
signal_pdm = in;
signal_pdm = signal_pdm(:); % Force en vecteur colonne
Fs_in = 6.144e6;  % 6.144 MHz

% --- FILTRE FIR (Equiripple) ---
load('FIR_Equiripple.mat');
b_fir = Num;

% --- FILTRE IIR (Butterworth) ---
data_butter = load('IIR_Butterworth.mat');
sos_butter = data_butter.SOS;
g_butter = data_butter.G;

% --- FILTRE IIR (Chebyshev Type 1) ---
data_cheby1 = load('IIR_Chebyshev_1.mat');
sos_cheby1 = data_cheby1.SOS;
g_cheby1 = data_cheby1.G;

% --- FILTRE IIR (Chebyshev Type 2) ---
data_cheby2 = load('IIR_Chebyshev_2.mat');
sos_cheby2 = data_cheby2.SOS;
g_cheby2 = data_cheby2.G;


%% 2. APPLICATION DES FILTRES
fprintf('Application du filtre FIR (Equiripple)...\n');
y_fir = filter(b_fir, 1, signal_pdm);

fprintf('Application du filtre IIR (Butterworth)...\n');
y_butter = sosfilt(sos_butter, signal_pdm) * prod(g_butter);

fprintf('Application du filtre IIR (Chebyshev Type 1)...\n');
y_cheby1 = sosfilt(sos_cheby1, signal_pdm) * prod(g_cheby1);

fprintf('Application du filtre IIR (Chebyshev Type 2)...\n');
y_cheby2 = sosfilt(sos_cheby2, signal_pdm) * prod(g_cheby2);


%% 3. ANALYSE SPECTRALE (Bande Audio 0-20kHz)
fprintf('Calcul des spectres FFT...\n');

L = length(signal_pdm);
N_fft = 2^nextpow2(L);
f = Fs_in*(0:(N_fft/2))/N_fft;

% Fonction locale pour calculer le spectre en dB
calc_db = @(sig) 20*log10( abs(fft(sig, N_fft)/L).*(1:N_fft)'*0+1 + eps );

% Calculs (On ne garde que la première moitié P1 pour l'affichage)
raw_fft = fft(signal_pdm, N_fft);
P2 = abs(raw_fft/L); P1_pdm = P2(1:N_fft/2+1); P1_pdm(2:end-1) = 2*P1_pdm(2:end-1);
spec_pdm = 20*log10(P1_pdm + eps);

raw_fft = fft(y_fir, N_fft);
P2 = abs(raw_fft/L); P1 = P2(1:N_fft/2+1); P1(2:end-1) = 2*P1(2:end-1);
spec_fir = 20*log10(P1 + eps);

raw_fft = fft(y_butter, N_fft);
P2 = abs(raw_fft/L); P1 = P2(1:N_fft/2+1); P1(2:end-1) = 2*P1(2:end-1);
spec_butter = 20*log10(P1 + eps);

raw_fft = fft(y_cheby1, N_fft);
P2 = abs(raw_fft/L); P1 = P2(1:N_fft/2+1); P1(2:end-1) = 2*P1(2:end-1);
spec_cheby1 = 20*log10(P1 + eps);

raw_fft = fft(y_cheby2, N_fft);
P2 = abs(raw_fft/L); P1 = P2(1:N_fft/2+1); P1(2:end-1) = 2*P1(2:end-1);
spec_cheby2 = 20*log10(P1 + eps);


%% 4. AFFICHAGE COMPARATIF
figure('Name', 'Comparaison Spectrale (Bande Audio)', 'Color', 'w');

% On trace
semilogx(f, spec_pdm,    'Color', [0.8 0.8 0.8], 'LineWidth', 1,   'DisplayName', 'PDM Input (Brut)'); hold on;
semilogx(f, spec_fir,    'b',                    'LineWidth', 1.5, 'DisplayName', 'FIR : Equiripple');
semilogx(f, spec_butter, 'r--',                  'LineWidth', 1.2, 'DisplayName', 'IIR : Butterworth');
semilogx(f, spec_cheby1, 'g-.',                  'LineWidth', 1.2, 'DisplayName', 'IIR : Cheby 1');
semilogx(f, spec_cheby2, 'm:',                   'LineWidth', 1.5, 'DisplayName', 'IIR : Cheby 2');
hold off;

% Mise en forme
grid on;
title('Comparaison des Spectres dans la Bande Audio (0 - 20 kHz)');
xlabel('Fréquence (Hz)');
ylabel('Amplitude (dB)');
legend('Location', 'southwest');

% ZOOM SUR LA BANDE AUDIO
xlim([20 20000]); 
ylim([-120 0]); % Ajustez selon la dynamique du signal

fprintf('Terminé.\n');