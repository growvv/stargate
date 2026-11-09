# -*- coding: utf-8 -*-
"""Build the narrated StarGate demo video from exported slides and TTS audio."""
import json
import math
import os
import subprocess
import wave

import imageio_ffmpeg
import numpy as np

BASE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(BASE)
ROOT = os.path.dirname(os.path.dirname(MOD))
SLIDES = os.path.join(MOD, 'render_hd')
AUDIO = os.path.join(BASE, 'audio')
CLIPS = os.path.join(BASE, 'clips')
OUT = os.path.join(ROOT, 'submission', 'StarGate_演示视频.mp4')
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FPS = 30
RATE = 24000
LEAD = 0.25
TAIL = 0.45
GAP = 0.15


def read_wav(path):
    with wave.open(path, 'rb') as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1 and w.getsampwidth() == 2
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).copy()


def write_wav(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.asarray(samples, dtype=np.int16).tobytes())


def make_music(n, rng):
    """Soft, slow chord pad; intentionally low in the mix."""
    t = np.arange(n, dtype=np.float64) / RATE
    chords = [
        [130.81, 196.00, 329.63, 493.88, 587.33],   # Cmaj9
        [110.00, 164.81, 261.63, 392.00, 493.88],   # Am9
        [87.31, 130.81, 220.00, 329.63, 392.00],    # Fmaj9
        [98.00, 146.83, 246.94, 329.63, 440.00],    # G6
    ]
    seg_len = 9.0
    xfade = 3.0
    music = np.zeros(n, dtype=np.float64)
    starts = np.arange(0, max(1.0, n / RATE - 0.5), seg_len)
    for k, st in enumerate(starts):
        freq = chords[k % len(chords)]
        a = int(st * RATE)
        b = min(n, int((st + seg_len + xfade) * RATE))
        if b <= a:
            continue
        tt = np.arange(b - a) / RATE
        env = np.minimum(1.0, tt / xfade) * np.minimum(1.0, (tt[-1] + 1 / RATE - tt) / xfade)
        voice = np.zeros_like(tt)
        for f in freq:
            vib = 1.0 + 0.0025 * np.sin(2 * np.pi * 0.13 * tt + rng.random() * 6.28)
            phase = 2 * np.pi * f * np.cumsum(vib) / RATE + rng.random() * 6.28
            voice += np.sin(phase) + 0.28 * np.sin(2 * phase) + 0.10 * np.sin(3 * phase)
        music[a:b] += voice * env * (0.9 if k % 2 == 0 else 0.75)
    # one-pole low pass to remove edge from the partials
    alpha = 0.18
    for _ in range(2):
        music = np.concatenate(([music[0]], music[1:] * alpha + music[:-1] * (1 - alpha)))
    music -= music.mean()
    peak = np.max(np.abs(music)) or 1.0
    music = music / peak * 0.11
    fade_in = int(3.0 * RATE)
    fade_out = int(5.0 * RATE)
    music[:fade_in] *= np.linspace(0, 1, fade_in)
    music[-fade_out:] *= np.linspace(1, 0, fade_out)
    return music


def main():
    data = json.load(open(os.path.join(BASE, 'script.json'), encoding='utf-8'))
    all_audio = []
    durations = []
    for seg in data:
        pieces = []
        for j in range(len(seg['sentences'])):
            pieces.append(read_wav(os.path.join(BASE, 'tts', 's%02d_%02d.wav' % (seg['id'], j + 1))))
        body = pieces[0]
        for p in pieces[1:]:
            body = np.concatenate([body, np.zeros(int(GAP * RATE), dtype=np.int16), p])
        lead = np.zeros(int(LEAD * RATE), dtype=np.int16)
        tail = np.zeros(int(TAIL * RATE), dtype=np.int16)
        seq = np.concatenate([lead, body, tail])
        frames = int(math.ceil(len(seq) / RATE * FPS))
        dur = frames / FPS
        target = int(round(dur * RATE))
        if len(seq) < target:
            seq = np.concatenate([seq, np.zeros(target - len(seq), dtype=np.int16)])
        else:
            seq = seq[:target]
        write_wav(os.path.join(AUDIO, 'seg%02d.wav' % seg['id']), seq)
        all_audio.append(seq)
        durations.append(dur)
        print('seg %02d %-6s %6.2fs  %d frames' % (seg['id'], seg['name'], dur, frames), flush=True)

    voice = np.concatenate(all_audio)
    total = len(voice) / RATE
    print('total %.2fs = %d:%05.2f' % (total, int(total // 60), total % 60), flush=True)

    rng = np.random.default_rng(20261109)
    music = make_music(len(voice), rng)
    v = voice.astype(np.float64) / 32768.0
    peak = np.max(np.abs(v)) or 1.0
    if peak > 0.88:
        v = v / peak * 0.88
    mixed = np.tanh((v + 0.40 * music) * 1.02) * 0.96
    write_wav(os.path.join(AUDIO, 'mix.wav'), (mixed * 32767).astype(np.int16))
    print('mixed audio written', flush=True)

    # ---- video clips -----------------------------------------------------
    variants = [0, 2, 1, 3]
    for idx, seg in enumerate(data):
        dur = durations[idx]
        frames = int(round(dur * FPS))
        step = 0.05 / max(1, frames)
        v = variants[idx % len(variants)]
        if v == 0:
            z = "min(zoom+%.8f,1.05)" % step
            x = "iw/2-(iw/zoom/2)"
            y = "ih/2-(ih/zoom/2)"
        elif v == 2:
            z = "if(eq(on,0),1.05,max(zoom-%.8f,1.0))" % step
            x = "iw/2-(iw/zoom/2)"
            y = "ih/2-(ih/zoom/2)"
        elif v == 1:
            z = "1.04"
            x = "(iw-iw/zoom)*on/%d" % max(1, frames - 1)
            y = "ih/2-(ih/zoom/2)"
        else:
            z = "1.04"
            x = "(iw-iw/zoom)*(1-on/%d)" % max(1, frames - 1)
            y = "ih/2-(ih/zoom/2)"
        vf = ("scale=3840:2160:flags=lanczos,"
              "zoompan=z='%s':x='%s':y='%s':d=1:s=1920x1080:fps=%d,format=yuv420p" % (z, x, y, FPS))
        if idx == 0:
            vf += ",fade=t=in:st=0:d=0.7"
        if idx == len(data) - 1:
            vf += ",fade=t=out:st=%.3f:d=1.0" % (dur - 1.0)
        src = os.path.join(SLIDES, 'slide%02d.png' % seg['slide'])
        dst = os.path.join(CLIPS, 'seg%02d.mp4' % seg['id'])
        cmd = [FFMPEG, '-y', '-loop', '1', '-framerate', str(FPS), '-i', src,
               '-t', '%.3f' % dur, '-vf', vf, '-an',
               '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
               '-r', str(FPS), '-pix_fmt', 'yuv420p', dst]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print('clip %02d ok' % seg['id'], flush=True)

    list_path = os.path.join(CLIPS, 'list.txt')
    with open(list_path, 'w', encoding='utf-8') as f:
        for seg in data:
            f.write("file '%s'\n" % os.path.join(CLIPS, 'seg%02d.mp4' % seg['id']).replace('\\', '/'))
    silent = os.path.join(CLIPS, 'silent.mp4')
    subprocess.run([FFMPEG, '-y', '-f', 'concat', '-safe', '0', '-i', list_path,
                    '-c', 'copy', '-fflags', '+genpts', silent], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('silent concat ok', flush=True)

    subprocess.run([FFMPEG, '-y', '-i', silent, '-i', os.path.join(AUDIO, 'mix.wav'),
                    '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
                    '-movflags', '+faststart', '-shortest',
                    '-metadata', 'title=星门 StarGate 演示视频', OUT],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('video written:', OUT, flush=True)


if __name__ == '__main__':
    main()
