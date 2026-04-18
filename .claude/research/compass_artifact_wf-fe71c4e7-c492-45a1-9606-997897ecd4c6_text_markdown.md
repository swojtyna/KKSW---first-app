# 20+ modeli AI z Hugging Face do deploymentu on-device na iOS w 2026

Poniżej kurowana lista **21 modeli** (LLM, Vision, Speech, Multimodal, Specjalistyczne) zaktualizowanych na Hugging Face **po 18 października 2025**, gotowych do uruchomienia na iPhone/iPad przez **Core ML** albo **MLX Swift**. Najmocniejsza oferta to obecnie **ekosystem speech** (Argmax WhisperKit/TTSKit, FluidAudio, Kokoro, Parakeet, Qwen3-ASR/TTS) — wszystkie z gotowymi Swift Package'ami i aktywnie rozwijane. Po stronie **LLM** dominuje `mlx-community` z rodzinami **Qwen3, Llama 3.2, SmolLM3, LFM2, Gemma 3, Phi-4-mini**, które ładuje się jedną linijką w `mlx-swift-examples`. Oficjalna organizacja **apple/** na HF w ostatnich 6 miesiącach publikowała głównie **modele badawcze** (StarFlow, SHARP, CLaRa, DiffuCoder) na licencji `apple-amlr` — nie mają one demo iOS, więc flagowe modele Apple do produktu (FastVLM, MobileCLIP2, Depth Pro, FastViT) wpadają tuż poza okno 6 miesięcy i są wymienione jako *honorable mentions*. Największe luki to świeże community porty **Depth Anything V2**, **SAM 2** i **Real-ESRGAN** w Core ML — tam trzeba albo skonwertować samemu, albo sięgnąć po nieco starsze porty.

Wszystkie rozmiary to wartości po kwantyzacji (4-bit/8-bit/FP16) podane na kartach modeli. Daty potwierdzone na stronach HF na dzień **18 kwietnia 2026**.

---

## 1. LLM / czat / generacja tekstu (MLX Swift)

Wszystkie poniższe ładuje się w `mlx-swift-examples` / `mlx-swift-lm` jednym ID, np. `ModelConfiguration(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit-DWQ-2510")`. Wymagają iPhone'a z Metal GPU (symulator nie działa). Praktyczny limit na iPhone 13–16 to ~2 GB; iPhone 17 Pro / iPady 16 GB mogą ciągnąć 3–4 GB.

### 1.1 `mlx-community/Qwen3-4B-Instruct-2507-4bit-DWQ-2510`
- **Rozmiar:** 2.26 GB (4-bit DWQ — distillation-aware quantization)
- **Co robi:** Qwen3 4B Instruct, wariant „2507" (256k kontekst, bez trybu „thinking", lepsze instruction-following). DWQ-2510 to najnowsza, lepsza jakościowo kwantyzacja.
- **Pomysł na aplikację iOS:** offline asystent do analizy długich dokumentów PDF, kontrakty, czytanie rozdziałów książek w trybie podróży.
- **HF:** https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit-DWQ-2510
- **Demo iOS:** https://github.com/ml-explore/mlx-swift-examples (`MLXChatExample`)
- **Licencja:** Apache-2.0 (komercyjna OK)
- **Aktualizacja:** październik–grudzień 2025 (mlx-lm 0.28.2) ✅

### 1.2 `mlx-community/Qwen3-1.7B-4bit-DWQ`
- **Rozmiar:** **968 MB**
- **Co robi:** Qwen3 1.7B z DWQ — najlepszy stosunek jakości do rozmiaru na iPhone'a 6 GB RAM. Tryb hybrydowy reasoning.
- **Pomysł na aplikację iOS:** szybki czatbot w aplikacji fitness/produktywności, generowanie odpowiedzi email offline.
- **HF:** https://huggingface.co/mlx-community/Qwen3-1.7B-4bit-DWQ
- **Demo iOS:** mlx-swift-examples (`LLMRegistry.qwen3_1_7b_4bit` analogicznie)
- **Licencja:** Apache-2.0
- **Aktualizacja:** koniec 2025 (mlx-lm 0.26+) ✅

### 1.3 `mlx-community/Llama-3.2-3B-Instruct-4bit`
- **Rozmiar:** **1.81 GB**
- **Co robi:** Llama 3.2 3B Instruct w 4-bit — sprawdzony, ogólnoprzeznaczeniowy model, domyślnie preset w `LLMRegistry.llama3_2_3B_4bit`.
- **Pomysł na aplikację iOS:** „Siri bez chmury" — asystent głosowy pełniący funkcje tekstowe offline; streszczanie wiadomości push.
- **HF:** https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit
- **Demo iOS:** `mlx-swift-examples/Applications/LLMEval`
- **Licencja:** Llama 3.2 Community (komercyjnie OK < 700M MAU)
- **Aktualizacja:** odświeżana w Q4 2025 (repo aktywne) ⚠️ *zweryfikuj dokładną datę commita przed deployem*

### 1.4 `mlx-community/Llama-3.2-1B-Instruct-4bit`
- **Rozmiar:** **695 MB**
- **Co robi:** najlżejszy sensowny Llama — mieści się nawet na starszych iPhone'ach 4 GB. Dobry do smart reply, klasyfikacji, prostych pytań.
- **Pomysł na aplikację iOS:** keyboard extension z auto-completion, smart reply w aplikacji messagingowej.
- **HF:** https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit
- **Demo iOS:** mlx-swift-examples
- **Licencja:** Llama 3.2 Community
- **Aktualizacja:** aktywnie odświeżany Q4 2025 ⚠️ *zweryfikuj*

### 1.5 `mlx-community/LFM2-2.6B-4bit`
- **Rozmiar:** **1.45 GB**
- **Co robi:** **Liquid AI LFM2** — hybrydowa architektura (nie-transformer) celowo zaprojektowana pod edge/phone. 8 języków. Zwykle szybsza niż porównywalny Llama.
- **Pomysł na aplikację iOS:** tłumacz offline 8-językowy na wyjazdy, low-latency chat w wearables.
- **HF:** https://huggingface.co/mlx-community/LFM2-2.6B-4bit
- **Demo iOS:** mlx-swift-examples (ładowanie po ID)
- **Licencja:** LFM Open License (darmowa komercyjnie do pewnego progu przychodu)
- **Aktualizacja:** mlx-lm 0.28.0, **koniec 2025** ✅

### 1.6 `mlx-community/Phi-4-mini-instruct-4bit`
- **Rozmiar:** **2.16 GB**
- **Co robi:** Microsoft Phi-4-mini 3.8B — mocne reasoning i matematyka jak na klasę „mini", długi kontekst.
- **Pomysł na aplikację iOS:** aplikacja edukacyjna do matematyki/fizyki, tutor kodowania offline.
- **HF:** https://huggingface.co/mlx-community/Phi-4-mini-instruct-4bit
- **Demo iOS:** mlx-swift-examples (`LLMRegistry.phi4bit`)
- **Licencja:** MIT
- **Aktualizacja:** aktywny Q4 2025 ⚠️ *zweryfikuj commit*

### 1.7 `anemll/anemll-Qwen-Qwen3-1.7B-ctx2048_0.3.5`
- **Rozmiar:** ~1 GB, Core ML skompilowany **pod Apple Neural Engine** (nie GPU)
- **Co robi:** projekt ANEMLL — Qwen3 1.7B przepisany na ANE przez split na podmodele + stateful KV-cache. Znacznie niższy pobór energii niż MLX na GPU.
- **Pomysł na aplikację iOS:** asystent działający w tle w aplikacji, gdzie kluczowe jest zużycie baterii (zdrowie, journaling).
- **HF:** https://huggingface.co/anemll/anemll-Qwen-Qwen3-1.7B-ctx2048_0.3.5
- **Demo iOS:** https://github.com/Anemll/Anemll (demo iOS w repo)
- **Licencja:** Apache-2.0 (z bazy Qwen3)
- **Aktualizacja:** **8 kwietnia 2026** ✅

### 1.8 `anemll/anemll-google-gemma-3-4b-it-qat-int4-ctx4096_0.3.5`
- **Rozmiar:** Gemma 3 4B INT4 QAT, Core ML/ANE, kontekst 4096
- **Co robi:** QAT-owa (training-aware) kwantyzacja INT4 Gemmy 3 4B pod ANE — wyższa jakość niż post-hoc int4.
- **Pomysł na aplikację iOS:** asystent-RAG do notatek, dziennik z semantycznym wyszukiwaniem, tutor językowy na iPadzie.
- **HF:** https://huggingface.co/anemll/anemll-google-gemma-3-4b-it-qat-int4-ctx4096_0.3.5
- **Demo iOS:** Anemll iOS demo
- **Licencja:** Gemma Terms of Use (komercyjnie OK z zastrzeżeniami)
- **Aktualizacja:** **13 kwietnia 2026** ✅

---

## 2. Mowa (ASR + TTS + diaryzacja)

Najbogatsza i najlepiej utrzymywana kategoria. Dwa główne ekosystemy: **Argmax** (WhisperKit, TTSKit) i **FluidInference** (FluidAudio — Parakeet, Kokoro, Qwen3-ASR/TTS, Sortformer).

### 2.1 `argmaxinc/whisperkit-coreml` ⭐ referencyjny ASR
- **Rozmiar:** warianty od **39 MB** (tiny) do **954 MB** (large-v3-turbo FP16); **632 MB** dla large-v3-turbo 4-bit QLoRA.
- **Co robi:** cała rodzina OpenAI Whisper (tiny→large-v3-turbo + distil-whisper) skompilowana do Core ML, odpalana na ANE. Bazowy model WhisperKit.
- **Pomysł na aplikację iOS:** offline podcast transcriber z ekspozycją plików .srt, accessibility live captions, voice memo z automatycznym summary.
- **HF:** https://huggingface.co/argmaxinc/whisperkit-coreml
- **Demo iOS:** https://github.com/argmaxinc/WhisperKit (SPM, TestFlight WhisperAX)
- **Licencja:** MIT (model + framework)
- **Aktualizacja:** **~1 kwietnia 2026** ✅

### 2.2 `argmaxinc/ttskit-coreml` 🆕 nowość Argmax
- **Rozmiar:** ~1 GB (Qwen3-TTS 0.6B); wariant 1.7B tylko macOS.
- **Co robi:** Qwen3-TTS skonwertowane do 6 komponentów Core ML ze streamowanym odtwarzaniem klatka-po-klatce. **9 głosów, 10 języków** (PL nie — ale EN/DE/FR/ES/IT/RU/PT/JA/KO/ZH). Wariant 1.7B przyjmuje prompty prozodyczne w języku naturalnym.
- **Pomysł na aplikację iOS:** audiobook reader z wyborem głosu, narracja dla gier RPG, accessibility reader dla dzieci.
- **HF:** https://huggingface.co/argmaxinc/ttskit-coreml
- **Demo iOS:** TTSKitExample w repo WhisperKit (iOS 18+)
- **Licencja:** Apache-2.0
- **Aktualizacja:** **16 kwietnia 2026** ✅

### 2.3 `FluidInference/parakeet-tdt-0.6b-v3-coreml` ⭐ najszybszy ASR EU
- **Rozmiar:** ~1.2–1.5 GB FP16 Core ML (0.6B params)
- **Co robi:** NVIDIA Parakeet TDT v3 (FastConformer) — **25 języków europejskich**, ~110× real-time na M4 Pro, word-level timestamps. Jakość i szybkość **powyżej Whisper large** przy niższym zużyciu pamięci.
- **Pomysł na aplikację iOS:** aplikacja dla reporterów europejskich, napisy live do streamów sportowych, indeksowanie podcastów do wyszukiwania po treści.
- **HF:** https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml
- **Demo iOS:** https://github.com/FluidInference/FluidAudio (SPM `FluidAudio` v0.12.4, iOS 17+)
- **Licencja:** CC-BY-4.0 (model) / Apache-2.0 (framework)
- **Aktualizacja:** **16 listopada 2025** ✅

### 2.4 `FluidInference/kokoro-82m-coreml` ⭐ najlepszy mały TTS
- **Rozmiar:** ~160–200 MB bundle Core ML (peak RAM ~1.5 GB przy syntezie)
- **Co robi:** **Kokoro-82M** (StyleTTS2) pod ANE — 54 głosy, 9–10 języków, ~23× real-time. W benchmarkach szybszy od MLX-owych odpowiedników.
- **Pomysł na aplikację iOS:** meditation/relaxation app z narracją na żywo, aplikacja do nauki wymowy języków obcych, TTS w klawiaturze iOS (keyboard extension).
- **HF:** https://huggingface.co/FluidInference/kokoro-82m-coreml
- **Demo iOS:** FluidAudio SPM (`KokoroTtsManager`); alternatywnie MLX: https://github.com/mlalma/kokoro-ios
- **Licencja:** Apache-2.0
- **Aktualizacja:** **~16 kwietnia 2026** ✅

### 2.5 `FluidInference/qwen3-asr-0.6b-coreml` 🆕
- **Rozmiar:** ~1.9 GB BF16 / ~728 MB RAM w wariancie int8
- **Co robi:** Qwen3-ASR 0.6B (audio encoder + 28-warstwowy dekoder Qwen3) na Core ML z stateful MLState KV-cache. **52 języki**, w tym mandaryński, kantoński, koreański. WER ~5% na LibriSpeech.
- **Pomysł na aplikację iOS:** globalny tłumacz głosowy na podróże, międzynarodowe meeting notes, aplikacja dla tłumaczy symultanicznych.
- **HF:** https://huggingface.co/FluidInference/qwen3-asr-0.6b-coreml
- **Demo iOS:** FluidAudio (`Qwen3AsrManager`, `Qwen3StreamingManager`)
- **Licencja:** Apache-2.0
- **Aktualizacja:** **8 kwietnia 2026** ✅

### 2.6 `FluidInference/parakeet-realtime-eou-120m-coreml`
- **Rozmiar:** 120M params, pipeline RNNT 3-częściowy Core ML, chunki 160/320 ms
- **Co robi:** streaming ASR z automatyczną detekcją końca wypowiedzi (EOU) — idealne do push-to-talk i dyktowania.
- **Pomysł na aplikację iOS:** voice-first UI bez przycisku „stop", live captioning do FaceTime, voice messagingowy snapchat.
- **HF:** https://huggingface.co/FluidInference/parakeet-realtime-eou-120m-coreml
- **Demo iOS:** FluidAudio (`StreamingEouAsrManager`)
- **Licencja:** NVIDIA Open Model License (komercyjnie OK z warunkami)
- **Aktualizacja:** mid-kwiecień 2026 ✅

### 2.7 `FluidInference/diar-streaming-sortformer-coreml`
- **Rozmiar:** Sortformer v2.1 (17 warstw Fast-Conformer + 18 warstw Transformer)
- **Co robi:** **diaryzacja mówców** streamingowo, do 10 osób, update co 100 ms, ~120× real-time. Pair-it z Whisper/Parakeet dla pełnego „kto co powiedział".
- **Pomysł na aplikację iOS:** transkrypcja podcastów/wywiadów z etykietami mówców, aplikacja do spotkań rekrutacyjnych/terapeutycznych.
- **HF:** https://huggingface.co/FluidInference/diar-streaming-sortformer-coreml
- **Demo iOS:** FluidAudio (`DiarizerManager`)
- **Licencja:** NVIDIA Open Model License
- **Aktualizacja:** **~17 kwietnia 2026** ✅

### 2.8 `TheStageAI/thewhisper-large-v3-turbo`
- **Rozmiar:** 0.8B, warianty S/M/L/XL skompilowane przez ANNA compiler
- **Co robi:** Whisper large-v3-turbo zoptymalizowany pod **minimalny pobór energii** na Apple Silicon; zmienne długości chunków (10/15/20/30 s) bez padding ciszy.
- **Pomysł na aplikację iOS:** transkrypcja na Apple Watch / w wearables, wielogodzinne sesje recordingowe na iPhone'ie bez drenowania baterii.
- **HF:** https://huggingface.co/TheStageAI/thewhisper-large-v3-turbo
- **Demo iOS:** https://github.com/TheStageAI/TheWhisper (głównie macOS demo, SDK eksponuje Core ML engine)
- **Licencja:** TheStage AI custom (Apache-2.0-style dla bazy)
- **Aktualizacja:** **16 kwietnia 2026** ✅

---

## 3. Wizja i multimodalne (VLM, segmentacja, detekcja, embeddingi)

### 3.1 `moondream/md3p-int4` — VLM MLX z OCR
- **Rozmiar:** **6.96 GB** (int4 MoE) — **za duże na iPhone'a, tylko iPad Pro M-class / Mac**
- **Co robi:** Moondream 3 Preview — MoE VLM z grounding, OCR, pointing, caption, VQA.
- **Pomysł na aplikację iOS (iPad):** iPad-owy asystent wizualny dla osób słabowidzących, skaner faktur z ekstrakcją pozycji, wizualny Q&A dla nauczycieli.
- **HF:** https://huggingface.co/moondream/md3p-int4
- **Demo iOS:** mlx-swift-examples VLM pipeline + mlx-vlm
- **Licencja:** Apache-2.0
- **Aktualizacja:** **~styczeń 2026** ✅

### 3.2 `Ultralytics/YOLO26` — detekcja/segmentacja/pose one-stop
- **Rozmiar:** YOLO26n ~**5 MB** FP16 Core ML → YOLO26x ~200 MB. Warianty: detect, -seg, -pose, -cls, -obb.
- **Co robi:** najnowsza rodzina Ultralytics YOLO (wrzesień/październik 2025, aktywnie maintained). Jedno-linijkowy eksport: `model.export(format="coreml")`.
- **Pomysł na aplikację iOS:** detekcja produktów na półkach dla merchandiserów, licznik ruchu, analiza formy treningowej (pose), sortownik zdjęć w galerii.
- **HF:** https://huggingface.co/Ultralytics/YOLO26
- **Demo iOS:** https://docs.ultralytics.com/integrations/coreml/ + oficjalna aplikacja Ultralytics iOS
- **Licencja:** AGPL-3.0 (enterprise płatna dla zamkniętych apek!)
- **Aktualizacja:** aktywnie rozwijane od wrz/paź 2025 ✅

### 3.3 `ZhengPeng7/BiRefNet` — usuwanie tła SOTA
- **Rozmiar:** ~440 MB FP16 safetensors (warianty GGUF 90–180 MB przez vision.cpp)
- **Co robi:** SOTA dichotomous image segmentation — usuwanie tła, salient object, camouflaged. Wariant `-matting` dla alpha-matte z włosami.
- **Pomysł na aplikację iOS:** profesjonalny „tło-remover" dla sklepów internetowych, narzędzie do przygotowywania zdjęć do sticker packs iMessage, virtual try-on.
- **HF:** https://huggingface.co/ZhengPeng7/BiRefNet
- **Demo iOS:** konwersja przez `huggingface/exporters` + swift-coreml; wzorzec `neuralize-ai/demo-conversion-coreml-briarmbg`
- **Licencja:** MIT (komercyjnie OK)
- **Aktualizacja:** **~17 kwietnia 2026** (fix pod transformers 5.5.0) ✅

### 3.4 `briaai/RMBG-2.0` — komercyjny model tła
- **Rozmiar:** ~440 MB FP16 (architektura BiRefNet, 1024×1024)
- **Co robi:** model tła trenowany na komercyjnym datasecie przez BRIA — 8-bit alpha matte.
- **Pomysł na aplikację iOS:** to samo co BiRefNet, ale gdy chcesz jakość bez ryzyk copyright — wymaga jednak licencji BRIA.
- **HF:** https://huggingface.co/briaai/RMBG-2.0
- **Demo iOS:** wzorce konwersji j.w.
- **Licencja:** **CC BY-NC 4.0 (non-commercial!)** — komercja tylko przez kontakt z BRIA
- **Aktualizacja:** **~17 grudnia 2025** ✅

### 3.5 `mlx-community/siglip2-base-patch16-224-8bit` — embeddingi wizualne
- **Rozmiar:** ~400 MB (8-bit MLX)
- **Co robi:** SigLIP 2 — wielojęzyczny encoder image-text do zero-shot classification, retrieval, wizualnego wyszukiwania w galerii.
- **Pomysł na aplikację iOS:** lokalny „Spotlight zdjęć" — szukaj po opisie tekstowym własnych fotek, automatyczne tagowanie, smart albumy.
- **HF:** https://huggingface.co/mlx-community/siglip2-base-patch16-224-8bit
- **Demo iOS:** mlx-swift-examples (embeddings path)
- **Licencja:** Apache-2.0
- **Aktualizacja:** ⚠️ *data niejasna na stronie — zweryfikuj commit history przed użyciem*

### 3.6 `mlx-community/nomicai-modernbert-embed-base-4bit` — embeddingi tekstu RAG
- **Rozmiar:** ~**150 MB** (4-bit)
- **Co robi:** ModernBERT embeddingi długiego kontekstu — RAG na urządzeniu, semantyczne wyszukiwanie notatek.
- **Pomysł na aplikację iOS:** Obsidian-style app z semantycznym search notatek, „chat z moim PDF" offline (w parze z Qwen3-1.7B).
- **HF:** https://huggingface.co/mlx-community/nomicai-modernbert-embed-base-4bit
- **Demo iOS:** mlx-swift-examples + MLXEmbedders
- **Licencja:** Apache-2.0
- **Aktualizacja:** ⚠️ *zweryfikuj commit*

---

## 4. Badawcze modele Apple (honorable mentions — w oknie, ale bez demo iOS)

Te modele są świeże i pochodzą z oficjalnej organizacji `apple/`, ale to publikacje badawcze (często 7B+, licencja `apple-amlr` = tylko research/demo, brak aplikacji iOS). Wymieniam dla kompletności.

### 4.1 `apple/starflow`
- **Rozmiar:** ~15.5 GB (3B text-to-image + 7B text-to-video) — **nie nadaje się bezpośrednio na telefon**
- **Co robi:** transformer normalizing-flow do wysokiej jakości T2I (256×256) i T2V (480p). NeurIPS 2025 Spotlight.
- **Zastosowanie:** inspiracja do dalszej destylacji; można uruchomić na Mac Studio w formie usługi dla swojej apki.
- **HF / GitHub:** https://huggingface.co/apple/starflow / https://github.com/apple/ml-starflow
- **Licencja:** apple-amlr (research only)
- **Aktualizacja:** **29 stycznia 2026** ✅

### 4.2 `apple/Sharp`
- **Rozmiar:** jeden checkpoint wagi, output ~1.2M Gaussianów
- **Co robi:** feed-forward 3D Gaussian view synthesis z pojedynczego zdjęcia w <1s — „zdjęcie → scena 3D".
- **Pomysł na aplikację iOS:** AR preview z jednego zdjęcia (community port Core ML: `pearsonkyle/Sharp-coreml`, ~1.9 s na M4 Max — realistyczny na iPadzie Pro).
- **HF / GitHub:** https://huggingface.co/apple/Sharp / https://github.com/apple/ml-sharp
- **Licencja:** apple-amlr
- **Aktualizacja:** **18 grudnia 2025** ✅

### 4.3 `apple/DiffuCoder-7B-cpGRPO`
- **Rozmiar:** 7B (bf16, ~14 GB) — **za duże na iPhone**
- **Co robi:** diffusion-based code LLM z coupled-GRPO RL — generacja kodu z non-autoregresywnym dekodowaniem.
- **Zastosowanie:** potencjalny backend dla code-completion app; wymaga destylacji do mniejszego modelu.
- **HF / GitHub:** https://huggingface.co/apple/DiffuCoder-7B-cpGRPO / https://github.com/apple/ml-diffucoder
- **Licencja:** Apple research
- **Aktualizacja:** **8 grudnia 2025** ✅

### 4.4 `apple/CLaRa-7B-Instruct`
- **Rozmiar:** 2.63 GB (adaptery na Mistral-7B) z kompresją dokumentów 16× i 128×
- **Co robi:** unified RAG z wbudowaną semantyczną kompresją — „zmieść 128× więcej kontekstu w tym samym tokenie".
- **Zastosowanie:** wzorzec dla własnego RAG-a na iPadzie (adaptery same są małe, ale Mistral-7B nadal duży).
- **HF / GitHub:** https://huggingface.co/apple/CLaRa-7B-Instruct / https://github.com/apple/ml-clara
- **Licencja:** apple-amlr
- **Aktualizacja:** **11 grudnia 2025** ✅

**⚠️ Poza oknem (wrzesień 2025) ale warte wzmianki** — flagowe modele Apple do produktu na iPhone'a: `apple/FastVLM-0.5B-fp16` (VLM, ~1 GB), `apple/coreml-mobileclip2-*` (embeddingi image-text), `apple/DepthPro`, `apple/FastViT`. Nie były odświeżane od września 2025, ale technicznie nadal działają i mają **gotowe demo iOS w repo ml-fastvlm, ml-mobileclip, ml-depth-pro, ml-fastvit**. Jeśli kryterium 6-miesięczne traktujesz miękko, to są to najlepsze „apple/" modele do wdrożenia.

---

## Rekomendacje — TOP 3 dla szybkiego startu

**🥇 1. WhisperKit (`argmaxinc/whisperkit-coreml`) + TTSKit (`argmaxinc/ttskit-coreml`).** Najlepsza dokumentacja w całym zestawie, 6k gwiazdek na GitHub, Swift Package działa na `pod init`, TestFlight demo WhisperAX można pobrać i zobaczyć działanie w 5 minut. Zacznij tu jeśli robisz cokolwiek związanego z audio. Licencja MIT.

**🥈 2. FluidAudio SPM z Kokoro TTS + Parakeet ASR (`FluidInference/*`).** Jedna paczka Swift pokrywa ASR (52 języki z Qwen3-ASR, 25 EU z Parakeet), TTS (Kokoro 9 języków, Qwen3-TTS 10), diaryzację (Sortformer) i VAD. Aktualizowana co kilka dni, iOS 17+, Apache-2.0. Najlepszy „szwajcarski scyzoryk" dla aplikacji głosowych.

**🥉 3. mlx-swift-examples + `mlx-community/Qwen3-1.7B-4bit-DWQ` (968 MB).** Najłatwiejsza droga do LLM-a w aplikacji: sklonuj `ml-explore/mlx-swift-examples`, otwórz `MLXChatExample.xcodeproj`, zmień ID modelu na Qwen3-1.7B-DWQ, buduj. Chat działa na iPhone'ie 13+ bez dalszej konfiguracji. Apache-2.0, komercyjnie czyste.

**Bonus, jeśli robisz vision:** `Ultralytics/YOLO26` z jednolinijkowym eksportem do Core ML pokrywa detekcję, segmentację, pose i klasyfikację w rodzinie modeli od 5 MB do 200 MB — ale uważaj na **AGPL-3.0** (dla zamkniętej komercji kup licencję Enterprise).

---

## Kluczowe wnioski

Ekosystem **iOS on-device AI rozpadł się w 2026 na trzy praktyczne ścieżki**: (1) Core ML via ANE dla maksymalnej efektywności energetycznej (ANEMLL, WhisperKit, FluidAudio), (2) MLX Swift na GPU dla LLM 1–4B z łatwym ładowaniem z HF, (3) Foundation Models framework Apple (WWDC 2025) dla natywnych LLM-ów systemowych bez własnych wag. Oficjalna organizacja `apple/` na HF w ostatnich 6 miesiącach publikowała **głównie modele badawcze 7B+** na `apple-amlr` — flagowe modele produktowe (FastVLM, MobileCLIP2, Depth Pro) stoją niezmienione od września 2025, co sugeruje, że Apple przesuwa produkcję do Foundation Models zamiast publikować nowe Core ML na HF. **Najszybszy rozwój dzieje się u trzecich stron**: Argmax, FluidInference, ANEMLL i mlx-community pushują nowe modele co kilka dni i to tam leży realna wartość dla buildera aplikacji.

Dla konkretnego produktu rekomendacja jest pragmatyczna: **zacznij od głosu** (WhisperKit/FluidAudio — działa dziś, out-of-the-box, komercyjne licencje), **dodaj LLM przez MLX Swift** (Qwen3-1.7B-DWQ lub Llama-3.2-3B) gdy już masz walidację, i **sięgaj po wizję** (YOLO26, BiRefNet, SigLIP 2) celowo pod konkretną feature'ę, a nie „bo się da". Unikaj modeli 7B+ na iPhone'ie — aż do iPhone'a 17 Pro nie ma tam sensu ze względu na pamięć i baterię.