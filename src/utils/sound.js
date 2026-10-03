// Sound Effects Utility for O Caro Deus Mercado
// Uses Web Audio API synthesizer for instant, reliable, zero-dependency retro sounds.

class SoundManager {
  constructor() {
    this.ctx = null;
    this.ready = false;
  }

  init() {
    try {
      if (!this.ctx) {
        const AudioCtx = typeof window !== 'undefined'
          ? (window.AudioContext || window.webkitAudioContext)
          : null;
        if (AudioCtx) {
          this.ctx = new AudioCtx();
        }
      }
      if (this.ctx) {
        if (this.ctx.state === 'suspended') {
          this.ctx.resume().then(() => { this.ready = true; });
        } else {
          this.ready = true;
        }
      }
    } catch (e) {
      // Audio not available
    }
  }

  ensureCtx() {
    this.init();
    return this.ctx && this.ready;
  }

  _createMasterGain() {
    const master = this.ctx.createGain();
    master.gain.setValueAtTime(0.5, this.ctx.currentTime);
    master.connect(this.ctx.destination);
    return master;
  }

  playCardPlay() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(400, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(180, this.ctx.currentTime + 0.12);

      gain.gain.setValueAtTime(0.4, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.12);

      osc.connect(gain);
      gain.connect(master);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.12);
    } catch (e) {
      // Audio fallback
    }
  }

  playCardDraw() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(250, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(600, this.ctx.currentTime + 0.09);

      gain.gain.setValueAtTime(0.35, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.09);

      osc.connect(gain);
      gain.connect(master);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.09);
    } catch (e) {
      // Audio fallback
    }
  }

  playPassTurn() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc1 = this.ctx.createOscillator();
      const osc2 = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc1.type = 'square';
      osc2.type = 'triangle';

      osc1.frequency.setValueAtTime(330, this.ctx.currentTime);
      osc1.frequency.setValueAtTime(440, this.ctx.currentTime + 0.08);

      osc2.frequency.setValueAtTime(440, this.ctx.currentTime);
      osc2.frequency.setValueAtTime(554, this.ctx.currentTime + 0.08);

      gain.gain.setValueAtTime(0.25, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.22);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(master);

      osc1.start();
      osc2.start();
      osc1.stop(this.ctx.currentTime + 0.22);
      osc2.stop(this.ctx.currentTime + 0.22);
    } catch (e) {
      // Audio fallback
    }
  }

  playVictory() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const notes = [523.25, 659.25, 783.99, 1046.50];
      notes.forEach((freq, index) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime + index * 0.12);

        gain.gain.setValueAtTime(0, this.ctx.currentTime + index * 0.12);
        gain.gain.setValueAtTime(0.4, this.ctx.currentTime + index * 0.12 + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + index * 0.12 + 0.35);

        osc.connect(gain);
        gain.connect(master);

        osc.start(this.ctx.currentTime + index * 0.12);
        osc.stop(this.ctx.currentTime + index * 0.12 + 0.35);
      });
    } catch (e) {
      // Audio fallback
    }
  }

  playDefeat() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const notes = [400, 350, 300, 220];
      notes.forEach((freq, index) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime + index * 0.15);

        gain.gain.setValueAtTime(0, this.ctx.currentTime + index * 0.15);
        gain.gain.setValueAtTime(0.35, this.ctx.currentTime + index * 0.15 + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + index * 0.15 + 0.3);

        osc.connect(gain);
        gain.connect(master);

        osc.start(this.ctx.currentTime + index * 0.15);
        osc.stop(this.ctx.currentTime + index * 0.15 + 0.3);
      });
    } catch (e) {
      // Audio fallback
    }
  }

  playBattleStart() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const notes = [330, 392, 523, 659];
      notes.forEach((freq, index) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime + index * 0.1);

        gain.gain.setValueAtTime(0, this.ctx.currentTime + index * 0.1);
        gain.gain.setValueAtTime(0.4, this.ctx.currentTime + index * 0.1 + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + index * 0.1 + 0.25);

        osc.connect(gain);
        gain.connect(master);

        osc.start(this.ctx.currentTime + index * 0.1);
        osc.stop(this.ctx.currentTime + index * 0.1 + 0.25);
      });
    } catch (e) {
      // Audio fallback
    }
  }

playFlip() {
     try {
       if (!this.ensureCtx()) return;

       const master = this._createMasterGain();
       const osc = this.ctx.createOscillator();
       const gain = this.ctx.createGain();

       osc.type = 'sine';
       osc.frequency.setValueAtTime(800, this.ctx.currentTime);
       osc.frequency.exponentialRampToValueAtTime(200, this.ctx.currentTime + 0.15);

       gain.gain.setValueAtTime(0.35, this.ctx.currentTime);
       gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.15);

       osc.connect(gain);
       gain.connect(master);

       osc.start();
       osc.stop(this.ctx.currentTime + 0.15);
     } catch (e) {
       // Audio fallback
     }
   }

   playDiceRoll() {
     try {
       if (!this.ensureCtx()) return;

       const master = this._createMasterGain();
       const osc = this.ctx.createOscillator();
       const gain = this.ctx.createGain();

       osc.type = 'triangle';
       osc.frequency.setValueAtTime(600, this.ctx.currentTime);
       osc.frequency.exponentialRampToValueAtTime(200, this.ctx.currentTime + 0.6);
       osc.frequency.exponentialRampToValueAtTime(800, this.ctx.currentTime + 0.7);
       osc.frequency.exponentialRampToValueAtTime(400, this.ctx.currentTime + 0.9);

       gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
       gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.9);

       osc.connect(gain);
       gain.connect(master);

       osc.start();
       osc.stop(this.ctx.currentTime + 0.9);
     } catch (e) {
       // Audio fallback
     }
   }

  playScoreGain() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const notes = [523, 659, 784];
      notes.forEach((freq, i) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime + i * 0.08);

        gain.gain.setValueAtTime(0.001, this.ctx.currentTime + i * 0.08);
        gain.gain.exponentialRampToValueAtTime(0.4, this.ctx.currentTime + i * 0.08 + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + i * 0.08 + 0.25);

        osc.connect(gain);
        gain.connect(master);

        osc.start(this.ctx.currentTime + i * 0.08);
        osc.stop(this.ctx.currentTime + i * 0.08 + 0.25);
      });
    } catch (e) {
      // Audio fallback
    }
  }

  playScoreLose() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(300, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(100, this.ctx.currentTime + 0.25);

      gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.25);

      osc.connect(gain);
      gain.connect(master);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.25);
    } catch (e) {
      // Audio fallback
    }
  }

  playParticleBurst() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(1200, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(400, this.ctx.currentTime + 0.1);

      gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.1);

      osc.connect(gain);
      gain.connect(master);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.1);
    } catch (e) {
      // Audio fallback
    }
  }

  playCardHighlight() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const notes = [880, 1109, 1319];
      notes.forEach((freq, i) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime + i * 0.1);

        gain.gain.setValueAtTime(0.001, this.ctx.currentTime + i * 0.1);
        gain.gain.exponentialRampToValueAtTime(0.3, this.ctx.currentTime + i * 0.1 + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + i * 0.1 + 0.35);

        osc.connect(gain);
        gain.connect(master);

        osc.start(this.ctx.currentTime + i * 0.1);
        osc.stop(this.ctx.currentTime + i * 0.1 + 0.35);
      });
    } catch (e) {
      // Audio fallback
    }
  }

  playSelect() {
    try {
      if (!this.ensureCtx()) return;

      const master = this._createMasterGain();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(600, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(900, this.ctx.currentTime + 0.06);

      gain.gain.setValueAtTime(0.25, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.06);

      osc.connect(gain);
      gain.connect(master);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.06);
    } catch (e) {
      // Audio fallback
    }
  }
}

export const soundManager = new SoundManager();
