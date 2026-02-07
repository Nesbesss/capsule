import { useState, useEffect } from "react";
import { listen } from "@tauri-apps/api/event";
import { motion, AnimatePresence } from "framer-motion";
import { Check } from "lucide-react";
import "./App.css";

function App() {
  const [amplitude, setAmplitude] = useState(0);
  const [transcription, setTranscription] = useState("");
  const [status, setStatus] = useState<"idle" | "recording" | "processing" | "success">("idle");

  useEffect(() => {
    const unlistenStarted = listen("recording-started", () => {
      setStatus("recording");
      setTranscription("");
    });

    const unlistenStopped = listen("recording-stopped", () => {
      setStatus("processing");
    });

    const unlistenAmp = listen<number>("amplitude", (event) => {
      // Smooth out amplitude if needed, but direct is distinct
      setAmplitude(event.payload);
    });

    const unlistenText = listen<string>("transcription", (event) => {
      setTranscription(event.payload);
      setStatus("success");
      setTimeout(() => setStatus("idle"), 2000);
    });

    return () => {
      unlistenStarted.then(f => f());
      unlistenStopped.then(f => f());
      unlistenAmp.then(f => f());
      unlistenText.then(f => f());
    };
  }, []);

  // Visualizer bars logic
  const bars = [1, 2, 3, 4, 5];

  return (
    <div className="container">
      <motion.div
        className="capsule"
        initial={{ scale: 0.9, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        style={{
          width: status === "processing" ? 200 : (status === "recording" ? 220 : 160)
        }}
      >
        <AnimatePresence mode="wait">
          {status === "idle" && (
            <motion.div
              key="idle"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex items-center gap-2 text-white/80 font-medium"
            >
              <div className="w-2 h-2 rounded-full bg-white/50" />
              <span>Ready</span>
            </motion.div>
          )}

          {status === "recording" && (
            <motion.div
              key="recording"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex items-center gap-1 h-full"
            >
              <motion.div
                animate={{ scale: [1, 1.2, 1] }}
                transition={{ duration: 1, repeat: Infinity }}
                className="w-2 h-2 rounded-full bg-red-500 mr-2"
              />
              {/* Simplified Sound Wave */}
              <div className="flex items-center gap-1 h-8">
                {bars.map((i) => (
                  <motion.div
                    key={i}
                    className="visualizer-bar bg-white"
                    animate={{
                      height: Math.max(4, Math.min(24, amplitude * 100 * (i % 2 === 0 ? 1.5 : 1) + 4))
                    }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  />
                ))}
                <motion.div
                  className="visualizer-bar bg-white/50"
                  animate={{
                    height: Math.max(4, Math.min(18, amplitude * 80 + 4))
                  }}
                />
                <motion.div
                  className="visualizer-bar bg-white/30"
                  animate={{
                    height: Math.max(4, Math.min(12, amplitude * 60 + 4))
                  }}
                />
              </div>
            </motion.div>
          )}

          {status === "processing" && (
            <motion.div
              key="processing"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex items-center gap-2 text-white font-medium"
            >
              <motion.div
                animate={{ rotate: 360 }}
                transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full"
              />
              <span>Thinking...</span>
            </motion.div>
          )}

          {status === "success" && (
            <motion.div
              key="success"
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="flex items-center gap-2 text-green-400 font-medium"
            >
              <Check size={16} />
              <span className="truncate max-w-[120px] text-white">
                {transcription || "Copied!"}
              </span>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}

export default App;
