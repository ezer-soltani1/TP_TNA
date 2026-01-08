%% TNA - Seance 3 : Banc de Filtres FREQUENTIEL (STFT)
% Fenêtrage -> FFT -> Masque -> IFFT -> Tuilage

clear; close all; clc;

%% 1. Chargement
fprintf('--- Chargement Données (Fréquentiel) ---\n');
filename = 'pcm_48k.mat';
if exist(filename, 'file')
    data = load(filename);
    vars = fieldnames(data);
    signal = double(data.(vars{1}));
    if size(signal,2) > 1, signal = mean(signal,2); end
    signal = signal / max(abs(signal));
else
    Fs = 48000;
    signal = randn(Fs*2, 1);
    warning('Signal de test généré (Bruit blanc).');
end
if ~exist('Fs', 'var'), Fs = 48000; end

%% 2. Configuration STFT
win_size = 1024;        % Taille de la fenêtre d'analyse
hop_size = win_size / 2; % Avancement (Overlap 50%)
window = hanning(win_size, 'periodic');

% Taille FFT (Puissance de 2 >= win_size pour efficacité)
nfft = 1024; 

% Gains (Mêmes que temporel pour comparaison : [0, 1])
gains_lin = [1, 0.8, 0.5, 0.2, 0];
gains_dB = 20*log10(gains_lin + eps);

%% 3. Construction du Masque Spectral
% On doit mapper les bins FFT aux bandes x0...x4
f_axis = (0:nfft/2) * (Fs/nfft);
mask_half = zeros(nfft/2 + 1, 1);

% Définition des limites (Dyadique inversé pour matcher le temporel)
% x4 (Haut) : Fs/4 à Fs/2
% x3        : Fs/8 à Fs/4
% ...
limits = [0, Fs/32, Fs/16, Fs/8, Fs/4, Fs/2];

for k = 1:5
    % Limites de la bande k
    f_start = limits(k);
    f_end = limits(k+1);
    
    % Sélection des indices FFT
    idx = f_axis >= f_start & f_axis < f_end;
    
    % Application du gain
    mask_half(idx) = gains_lin(k);
end

% Création du masque complet (Symétrie Hermitienne pour signal réel)
mask_full = [mask_half; flipud(mask_half(2:end-1))];

%% 4. Traitement par Blocs (Overlap-Add)
fprintf('--> Traitement STFT en cours...\n');

L = length(signal);
output_len = ceil(L / hop_size) * hop_size + nfft;
signal_out = zeros(output_len, 1);

% Variables pour la visualisation d'une étape intermédiaire (Debug)
capture_idx = round(L/2); % On vise le milieu du signal
debug_struct = struct(); 
captured = false;

pin = 1; % Pointeur d'entrée
while pin + win_size - 1 <= L
    % A. Extraction & Fenêtrage
    frame = signal(pin : pin + win_size - 1) .* window;
    
    % B. FFT
    FRAME_FFT = fft(frame, nfft);
    
    % C. Application Masque (Égalisation)
    FRAME_OUT = FRAME_FFT .* mask_full;
    
    % --- Capture pour visualisation (Figure 2) ---
    if ~captured && pin >= capture_idx
        debug_struct.time_frame = frame;
        debug_struct.spectrum_in = abs(FRAME_FFT(1:nfft/2+1));
        debug_struct.mask = mask_half;
        debug_struct.spectrum_out = abs(FRAME_OUT(1:nfft/2+1));
        debug_struct.freq_axis = f_axis;
        captured = true;
    end
    % ---------------------------------------------
    
    % D. IFFT
    frame_out = real(ifft(FRAME_OUT, nfft));
    
    % E. Overlap-Add (Addition dans le buffer de sortie)
    pout = pin;
    signal_out(pout : pout + nfft - 1) = signal_out(pout : pout + nfft - 1) + frame_out;
    
    % Avance
    pin = pin + hop_size;
end

% Troncature finale
signal_out = signal_out(1:L);

%% 5. Affichage Résultats
t = (0:L-1)/Fs;

% --- Figure 1 : Entrée vs Sortie (Zoom Temporel) ---
figure('Name', 'Comparaison Temporelle (Zoom)', 'Color', 'w');
t_start = 1.0; t_end = 1.05; % Zoom 50ms

subplot(2,1,1);
plot(t, signal, 'b');
title('Signal d''Entrée (Original) - Zoom 50ms');
xlabel('Temps (s)'); xlim([t_start t_end]); grid on;

subplot(2,1,2);
plot(t, signal_out, 'r');
title('Signal de Sortie (STFT) - Zoom 50ms');
xlabel('Temps (s)'); xlim([t_start t_end]); grid on;


% --- Figure 2 : Au cœur de l'algorithme (Étapes Intermédiaires) ---
if captured
    figure('Name', 'Étapes Intermédiaires (Une Frame)', 'Color', 'w');
    sgtitle('Traitement d''une fenêtre unique (Frame au milieu du signal)');
    
    % 1. Fenêtre Temporelle
    subplot(2,2,1);
    plot(debug_struct.time_frame, 'b');
    title('1. Fenêtre Temporelle (x[n] * w[n])');
    grid on; axis tight;
    
    % 2. Spectre Entrée
    subplot(2,2,2);
    plot(debug_struct.freq_axis, 20*log10(debug_struct.spectrum_in), 'b');
    title('2. Spectre FFT Entrée');
    xlabel('Fréquence (Hz)'); ylabel('Magnitude (dB)');
    xlim([20 20000]); grid on;
    
    % 3. Le Masque (Gain)
    subplot(2,2,3);
    stem(debug_struct.freq_axis, debug_struct.mask, 'g', 'Marker', 'none');
    title('3. Masque Spectral (Gains)');
    xlabel('Fréquence (Hz)'); ylabel('Gain Linéaire');
    xlim([20 20000]); grid on;
    
    % 4. Spectre Sortie
    subplot(2,2,4);
    plot(debug_struct.freq_axis, 20*log10(debug_struct.spectrum_out), 'r');
    title('4. Spectre FFT Sortie (Modifié)');
    xlabel('Fréquence (Hz)'); ylabel('Magnitude (dB)');
    xlim([20 20000]); grid on;
end


% --- Figure 3 : Analyse Globale ---
figure('Name', 'Analyse Globale (Fréquentiel)', 'Color', 'w');

% Spectrogramme
subplot(2,1,1);
spectrogram(signal_out, win_size, hop_size, nfft, Fs, 'yaxis');
title('Spectrogramme Signal Sortie');

% Comparaison PSD
subplot(2,1,2);
[p_in, f_p] = pwelch(signal, 1024, 512, 1024, Fs);
[p_out, ~] = pwelch(signal_out, 1024, 512, 1024, Fs);

semilogx(f_p, 10*log10(p_in), 'b', 'LineWidth', 1); hold on;
semilogx(f_p, 10*log10(p_out), 'r', 'LineWidth', 1.5);
stairs(limits(2:end), gains_dB, 'g--', 'LineWidth', 2); 

title('Comparaison Spectrale (PSD)');
legend('Entrée', 'Sortie', 'Gains Cibles');
xlabel('Fréquence (Hz)'); ylabel('dB/Hz');
xlim([20 20000]); grid on;

fprintf('Terminé. 3 Figures générées.\n');
