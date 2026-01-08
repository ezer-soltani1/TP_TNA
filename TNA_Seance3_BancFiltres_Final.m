%% TNA - Seance 3 : Banc de Filtres Multi-cadences & STFT
% Auteurs : Binome & Assistant (Gemini)
% Date : 05 Jan 2026
% Architecture : 
%   1. Temporel : Decomposition Dyadique (Sub-band) avec Decimation.
%   2. Frquentiel : STFT avec Overlap-Add.

clear; close all; clc;

%% --- 1. Prparation ---
fprintf('--- Chargement et Configuration ---\n');
filename = 'pcm_48k.mat';
if exist(filename, 'file')
    data = load(filename);
    vars = fieldnames(data);
    signal = double(data.(vars{1}));
    if size(signal,2) > 1, signal = mean(signal,2); end % Mono
    signal = signal / max(abs(signal)); % Normalisation
else
    Fs = 48000;
    signal = randn(Fs*2, 1); % Bruit blanc de test
    warning('Signal de test gnre.');
end

if ~exist('Fs', 'var'), Fs = 48000; end
L = length(signal);

% Gains EQ (Basses -> Aigus)
% x0(Basses), x1, x2, x3, x4(Aigus)

gains_dB = [12, 6, 0, -6, -12]; 
gains_lin = 10.^(gains_dB/20);
fprintf('Gains EQ : %s dB\n', mat2str(gains_dB));

%% --- 2. Approche Temporelle : Banc de Filtres Multi-cadences (Dyadique) ---
fprintf('\n--- 2. Approche Temporelle (Sub-band Coding) ---\n');
toc;

% Conception des filtres pour la dcomposition (Half-band filters)
% On utilise des filtres FIR pour la phase linaire (facilite la reconstruction)
% Ordre N=32 suffisant pour TP. Cutoff  0.5 (Nyquist/2)
N_filt = 64; 
b_low = fir1(N_filt, 0.5); 
b_high = fir1(N_filt, 0.5, 'high');

% Note: Pour une reconstruction parfaite thorique, on utiliserait des filtres QMF 
% ou des ondes. Ici, fir1 est une approximation "ingnieur" simple.

% -- ANALYSE (Dcomposition) --
% Structure : x -> [Splitting] -> H(High) -> x4
%                              -> L(Low) -> Downsample -> [Splitting] ...
subbands = cell(5, 1);
current_sig = signal;

for i = 4:-1:1
    % 1. Filtrage
    sig_low = filter(b_low, 1, current_sig);
    sig_high = filter(b_high, 1, current_sig);
    
    % 2. Dimation (Downsampling)
    % On garde 1chantillon sur 2. Attention au dlai du filtre !
    % Pour synchroniser, on peut compenser le retard de groupe (N/2).
    sig_low_down = sig_low(1:2:end);
    sig_high_down = sig_high(1:2:end);
    
    % Stockage de la bande haute
    subbands{i+1} = sig_high_down;
    
    % Le signal basse frquence continue vers l'tage suivant
    current_sig = sig_low_down;
end
subbands{1} = current_sig; % Le rsidu final (Basses frquences x0)

% -- TRAITEMENT (EQ & VU-mtre) --
vu_levels = zeros(5,1);
for k = 1:5
    % VU-Mtre (RMS)
    vu_levels(k) = rms(subbands{k});
    
    % Application du Gain
    subbands{k} = subbands{k} * gains_lin(k);
end

% -- SYNTHSE (Reconstruction) --
reconstructed_signal = subbands{1};

for i = 1:4
    % 1. Interpolation (Upsampling + Zeros)
    % Signal Low (venant de l'tage prcdent)
    len_target = length(subbands{i+1}) * 2; % Taille cible approx
    upsampled_low = zeros(len_target, 1);
    upsampled_low(1:2:end) = reconstructed_signal(1:length(subbands{i+1})); 
    
    % Signal High (stock)
    upsampled_high = zeros(len_target, 1);
    upsampled_high(1:2:end) = subbands{i+1};
    
    % 2. Filtrage d'interpolation (Anti-imagerie)
    % Il faut multiplier par 2 le gain aprs interpolation pour compenser l'nergie
    sig_rec_low = filter(b_low, 1, upsampled_low) * 2;
    sig_rec_high = filter(b_high, 1, upsampled_high) * 2;
    
    % 3. Sommation
    % Attention : Retard grer. filter() ajoute du dlai.
    % Dans une implmentation simple "TP", on accepte le dlai global.
    % On s'assure juste que les vecteurs ont la mme taille.
    min_len = min(length(sig_rec_low), length(sig_rec_high));
    reconstructed_signal = sig_rec_low(1:min_len) + sig_rec_high(1:min_len);
end

% Compensation basique du retard global pour comparaison (Dlai total ~ N_filt * nb_stages)
% Cette tape est souvent manuelle en TP.
signal_out_time = reconstructed_signal;
time_cost = toc;
fprintf('Temps calcul Temporel : %.4f s\n', time_cost);


%% --- 3. Approche Frquentielle : STFT (Overlap-Add) ---
fprintf('\n--- 3. Approche Frquentielle (Overlap-Add) ---\n');
toc;

% Paramtres STFT
win_len = 1024; % Taille fentre
hop_len = win_len / 2; % Recouvrement 50%
window = hanning(win_len, 'periodic');

% Zero-padding pour viter le repliement circulaire lors de la convolution frquentielle
nfft = 2^nextpow2(win_len); 

% Initialisation buffer sortie
output_len = ceil(L / hop_len) * hop_len + nfft;
signal_out_freq = zeros(output_len, 1);

% Dfinition des bandes en indices FFT (0  nfft/2)
f_axis = (0:nfft/2) * (Fs/nfft);
% Limites approximatives des bandes dyadiques (cales sur la logique temporelle)
% x4: Fs/4 - Fs/2
% x3: Fs/8 - Fs/4 ...
limits = [0, Fs/32, Fs/16, Fs/8, Fs/4, Fs/2]; 
mask_half = zeros(nfft/2 + 1, 1);

% Construction du Masque Spectral
% On assigne les gains aux bins FFT correspondants
for k = 1:5
    f_start = limits(k);
    f_end = limits(k+1);
    idx = f_axis >= f_start & f_axis < f_end;
    mask_half(idx) = gains_lin(k);
end
% Symtrie pour FFT
mask = [mask_half; flipud(mask_half(2:end-1))];
if length(mask) < nfft, mask(end+1) = mask(end); end % Scurit taille

% Boucle de traitement par blocs
current_idx = 1;
pin = 1;
while pin + win_len - 1 <= L
    % 1. Extraction et Fenmtrage
    segment = signal(pin : pin + win_len - 1) .* window;
    
    % 2. FFT
    SEG = fft(segment, nfft);
    
    % 3. Filtrage Spectral
    SEG_OUT = SEG .* mask;
    
    % 4. IFFT
    seg_out = real(ifft(SEG_OUT, nfft));
    
    % 5. Overlap-Add
    dest_idx = pin : pin + nfft - 1;
    signal_out_freq(dest_idx) = signal_out_freq(dest_idx) + seg_out;
    
    % Avance
    pin = pin + hop_len;
end

% Troncature  la taille originale
signal_out_freq = signal_out_freq(1:L);

freq_cost = toc;
fprintf('Temps calcul Frquentiel : %.4f s\n', freq_cost);

%% --- 4. Rsultats et Visualisation ---
figure('Name', 'Analyses TNA Sance 3', 'Color', 'w', 'Position', [100, 100, 1000, 600]);

% 1. VU-Mtre (Temporel)
subplot(2,2,1);
bar(vu_levels);
title('VU-mtre (RMS des sous-bandes)');
set(gca, 'XTickLabel', {'x0(Low)', 'x1', 'x2', 'x3', 'x4(High)'});
ylabel('Amplitude'); grid on;

% 2. Spectrogramme Entr
subplot(2,2,3);
spectrogram(signal, 1024, 512, 1024, Fs, 'yaxis');
title('Spectrogramme Original');

% 3. Comparaison Spectrale (PSD)
subplot(2,2, [2 4]);
hold on;
[p_in, f] = pwelch(signal, 1024, 512, 1024, Fs);
[p_out_t, ~] = pwelch(signal_out_time, 1024, 512, 1024, Fs);
[p_out_f, ~] = pwelch(signal_out_freq, 1024, 512, 1024, Fs);

plot(f, 10*log10(p_in), 'k', 'DisplayName', 'Original');
plot(f, 10*log10(p_out_t), 'b', 'LineWidth', 1.5, 'DisplayName', 'Temporel (Multi-cadence)');
plot(f, 10*log10(p_out_f), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Frquentiel (STFT)');
legend; grid on;
xlabel('Frquence (Hz)'); ylabel('PSD (dB)');
title('Comparaison des Sorties');
set(gca, 'XScale', 'log'); xlim([20 20000]);

fprintf('Script termin.\n');
