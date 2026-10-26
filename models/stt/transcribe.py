import sys
import os
import json

def main():
    if len(sys.argv) < 3:
        print(f"__RESULT_JSON__{json.dumps({'error': 'Usage: python transcribe.py <model_path> <audio_path>'})}")
        sys.exit(1)

    model_path = sys.argv[1]
    audio_path = sys.argv[2]

    if not os.path.exists(model_path):
        print(f"__RESULT_JSON__{json.dumps({'error': f'Model not found: {model_path}'})}")
        sys.exit(1)

    if not os.path.exists(audio_path):
        print(f"__RESULT_JSON__{json.dumps({'error': f'Audio file not found: {audio_path}'})}")
        sys.exit(1)

    try:
        from pywhispercpp.model import Model
        model = Model(model_path, n_threads=4, print_realtime=False, print_progress=False)
        segments = model.transcribe(audio_path)
        raw_text = " ".join([seg.text.strip() for seg in segments if seg.text.strip()]).strip()
        cleaned_text = raw_text.replace("[BLANK_AUDIO]", "").strip()
        print(f"__RESULT_JSON__{json.dumps({'text': cleaned_text})}")
    except Exception as e:
        print(f"__RESULT_JSON__{json.dumps({'error': str(e)})}")
        sys.exit(1)

if __name__ == "__main__":
    main()

