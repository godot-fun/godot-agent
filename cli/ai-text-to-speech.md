# ai-text-to-speech

Zero-shot TTS with IndexTTS2. Uses the **`index-tts`** venv (Python 3.11), not default `python`.

From repo root. Reference voice: `zhu_ba_jie.wav` in this folder. Needs a populated `index-tts` install.

Unix: `.dependency/index-tts/.venv/bin/python`

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/ai-text-to-speech/tts.py --voice .ai/test/audio/zhu_ba_jie.wav --text "你好，欢迎来到这个世界。" --output .ai/test/tts
```


```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/ai-text-to-speech/tts.py --voice .ai/test/audio/zhu_ba_jie.wav --text "Hello, welcome to this world."
```