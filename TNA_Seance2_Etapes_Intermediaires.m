%% TNA - SÉANCE 2 : ANALYSE DÉTAILLÉE ÉTAPE PAR ÉTAPE (CORRIGÉ)
% Ce script visualise le signal AVANT et APRÈS chaque bloc du SRC Naïf.
% Correction : Alignement spectral rigoureux.

clear; close all; clc;

%% 1. CHARGEMENT
if exist('playback_44100.mat', 'file')
    load('playback_44100.mat');
else
    error('Fichier playback_44100.mat introuvable.');
end

% Robustesse sur le nom de la variable
if exist('playback_44100', 'var'), x = playback_44100;
elseif exist('data', 'var'), x = data;
elseif exist('w441', 'var'), x = w441;
else, error('Variable audio introuvable.'); end

Fs_in = 44100;
Fs_out = 48000;
[L, M] = rat(Fs_out / Fs_in); % L=160, M=147

% PARAMÈTRES DE TRAITEMENT
start_sample = 10000; 
N_process = 1024; % Puissance de 2 pour des FFT propres
x_process = x(start_sample : start_sample + N_process - 1);

disp('--- ANALYSE ETAPE PAR ETAPE (Alignement Spectral) ---');
fprintf('Traitement de %d echantillons d''entree.\n', N_process);

%% ÉTAPE 1 : EXPANSION
x_up = upsample(x_process, L);
Fs_inter = Fs_in * L;

fprintf('Taille entree : %d -> Taille expanse : %d\n', length(x_process), length(x_up));

% --- FIGURE 1 : TEMPOREL ET SPECTRAL ---
figure('Name', 'Preuve Alignement Spectral', 'Color', 'w');

% 1. Temporel
subplot(2,1,1);
t_in = 0:N_process-1;
stem(t_in, x_process, 'b', 'LineWidth', 2); hold on;
t_up = (0:length(x_up)-1)/L;
stem(t_up, x_up, 'r.', 'MarkerSize', 1);
title('Domaine Temporel : Insertion de Zeros');
legend('Original', 'Expanse');
xlim([10 15]); grid on; % Zoom pour voir les zéros

% 2. Fréquentiel (CORRECTION ICI)
subplot(2,1,2);

% A. Spectre ORIGINAL (Calcul sur N points)
N_fft_in = length(x_process); 
X_in = fft(x_process);
f_in = (0:N_fft_in-1)*(Fs_in/N_fft_in); 

% B. Spectre EXPANSÉ (Calcul sur N*L points)
N_fft_up = length(x_up); 
X_up = fft(x_up);
f_up = (0:N_fft_up-1)*(Fs_inter/N_fft_up); 

% Affichage
% On trace d'abord le rouge (Expansé)
plot(f_up, 20*log10(abs(X_up)), 'r', 'LineWidth', 1); hold on;
% On trace le bleu (Original) par dessus
plot(f_in, 20*log10(abs(X_in)), 'b', 'LineWidth', 1.5);

title('Superposition des Spectres (Preuve mathematique)');
xlabel('Frequence (Hz)'); ylabel('Magnitude (dB)');
legend('Signal Expanse (Images)', 'Signal Original');
xlim([0 100000]); % On regarde jusqu''à 100kHz
grid on;
% Lignes verticales pour repères
xline(44100, 'k--', '44.1k');
xline(88200, 'k--', '88.2k');


%% ÉTAPE 2 : FILTRAGE (INTERPOLATION)
disp('Calcul du filtre et convolution (peut prendre ~5 secondes)...');
Fc = 22050; 
N_ordre = 2000;
b = fir1(N_ordre, Fc/(Fs_inter/2));

% Filtrage 
x_filt = filter(b, 1, x_up) * L;

% Correction délai visuelle
delay = N_ordre/2;
x_filt_shifted = [x_filt(delay+1:end); zeros(delay,1)];

% --- FIGURE 2 : FILTRAGE ---
figure('Name', 'ETAPE 2 : Filtrage', 'Color', 'w');

% Temporel
subplot(2,1,1);
stem(t_up, x_up, 'r.', 'MarkerSize', 1); hold on;
plot(t_up, x_filt_shifted, 'b', 'LineWidth', 1.5);
title('Domaine Temporel : Interpolation');
legend('Expanse (Zeros)', 'Filtre (Interpole)');
xlim([10 15]); % Zoom
grid on;

% Fréquentiel
subplot(2,1,2);
% Spectre filtré
X_filt = fft(x_filt); % Sur toute la longueur
plot(f_up, 20*log10(abs(X_up)), 'Color', [0.8 0.8 0.8]); hold on; % Gris
plot(f_up, 20*log10(abs(X_filt)), 'b', 'LineWidth', 1.5);
title('Domaine Frequentiel : Suppression des Images');
legend('Avant Filtre', 'Apres Filtre');
xlim([0 100000]); ylim([-50 80]);
grid on;


%% ÉTAPE 3 : DÉCIMATION
y_out = downsample(x_filt, M);
y_out_shifted = downsample(x_filt_shifted, M);

% --- FIGURE 3 : DÉCIMATION ---
figure('Name', 'ETAPE 3 : Decimation', 'Color', 'w');

% Temporel
subplot(2,1,1);
plot(t_up, x_filt_shifted, 'b'); hold on; 
t_out = (0:length(y_out_shifted)-1) * (M/L);
stem(t_out, y_out_shifted, 'go', 'LineWidth', 1.5, 'MarkerFaceColor', 'g');
title('Domaine Temporel : Prelevement (1 sur M)');
legend('Signal 7MHz', 'Signal 48kHz');
xlim([10 11]); % Zoom
grid on;

% Fréquentiel final
subplot(2,1,2);
[P_final, f_fin] = pwelch(y_out, hanning(512), 256, 1024, Fs_out);
plot(f_fin, 10*log10(P_final), 'g', 'LineWidth', 1.5);
title('Spectre Final (48kHz)');
xlabel('Frequence (Hz)'); ylabel('PSD (dB)');
grid on; xlim([0 24000]);

disp('Figures generees avec succes.');
