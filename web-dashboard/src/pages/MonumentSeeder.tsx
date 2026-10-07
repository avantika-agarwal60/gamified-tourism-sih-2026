import { useState } from "react";
import { Landmark, HelpCircle, Plus, Trash2 } from "lucide-react";
import PageHeader from "../components/PageHeader";
import { authFetch } from "../api/authFetch";

const API_BASE = "https://questination-production-08b6.up.railway.app";

interface QuestionInput {
  question: string;
  options: [string, string, string, string];
  correct_option: string;
}

function emptyQuestion(): QuestionInput {
  return { question: "", options: ["", "", "", ""], correct_option: "" };
}

function MonumentSeeder() {
  const [step, setStep] = useState<"quest" | "questions" | "done">("quest");

  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [description, setDescription] = useState("");
  const [qrCodeInput, setQrCodeInput] = useState("");
  const [lat, setLat] = useState("");
  const [lng, setLng] = useState("");
  const [xp, setXp] = useState("");

  const [questions, setQuestions] = useState<QuestionInput[]>([emptyQuestion()]);

  const [questId, setQuestId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function addQuestion() {
    setQuestions([...questions, emptyQuestion()]);
  }

  function removeQuestion(index: number) {
    if (questions.length === 1) return;
    setQuestions(questions.filter((_, i) => i !== index));
  }

  function updateQuestionText(index: number, value: string) {
    const updated = [...questions];
    updated[index] = { ...updated[index], question: value };
    setQuestions(updated);
  }

  function updateOption(qIndex: number, optIndex: number, value: string) {
    const updated = [...questions];
    const current = updated[qIndex];
    const oldValue = current.options[optIndex];
    const newOptions = [...current.options] as [string, string, string, string];
    newOptions[optIndex] = value;
    updated[qIndex] = {
      ...current,
      options: newOptions,
      correct_option: current.correct_option === oldValue ? value : current.correct_option,
    };
    setQuestions(updated);
  }

  function updateCorrectOption(qIndex: number, value: string) {
    const updated = [...questions];
    updated[qIndex] = { ...updated[qIndex], correct_option: value };
    setQuestions(updated);
  }

  async function handleCreateQuest() {
    if (!name || !city) return;
    setLoading(true);
    setError("");
    try {
      const finalQrCode = qrCodeInput || `${name.replace(/\s+/g, "-")}-${Date.now()}`;

      const response = await authFetch(`${API_BASE}/api/qr/quest`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          city,
          qr_code: finalQrCode,
          description,
          lat: Number(lat),
          lng: Number(lng),
          xp: Number(xp),
        }),
      });

      const rawText = await response.text();
      let data: any = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        setError(`Status ${response.status}. Raw response: ${rawText.slice(0, 300)}`);
        setLoading(false);
        return;
      }

      if (response.ok) {
        const id = data.id || data.quest?.id || data._id || data.questId;
        if (!id) {
          setError(`Quest created, but couldn't find its ID in the response: ${JSON.stringify(data)}`);
          setLoading(false);
          return;
        }
        setQuestId(id);
        setStep("questions");
      } else {
        setError(`Status ${response.status}: ${data?.message || JSON.stringify(data)}`);
      }
    } catch (err: any) {
      setError(`Network error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function handleSubmitQuestions() {
    if (!questId) return;

    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      const nonEmptyOptions = q.options.map((o) => o.trim()).filter(Boolean);

      if (!q.question.trim()) {
        setError(`Question ${i + 1}: enter a question.`);
        return;
      }
      if (nonEmptyOptions.length < 2) {
        setError(`Question ${i + 1}: enter at least two options.`);
        return;
      }
      if (!q.correct_option.trim() || !nonEmptyOptions.includes(q.correct_option.trim())) {
        setError(`Question ${i + 1}: select a correct option.`);
        return;
      }
    }

    setLoading(true);
    setError("");
    try {
      for (let i = 0; i < questions.length; i++) {
        const q = questions[i];
        const response = await authFetch(`${API_BASE}/api/qr/quest/${questId}/questions`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            question: q.question,
            options: q.options,
            correct_option: q.correct_option,
          }),
        });

        if (!response.ok) {
          const rawText = await response.text();
          setError(`Question ${i + 1} failed (status ${response.status}): ${rawText.slice(0, 300)}`);
          setLoading(false);
          return;
        }
      }

      setStep("done");
    } catch (err: any) {
      setError(`Network error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <PageHeader title="Add Monument" subtitle="Seed a new heritage site into the platform." />

      {step === "quest" && (
        <div className="bg-white p-8 rounded-2xl shadow-lg shadow-emerald-900/5 border border-amber-100 w-full max-w-md">
          <div className="flex items-center gap-2 mb-4 text-emerald-700">
            <Landmark size={22} />
            <span className="font-semibold">Monument Details</span>
          </div>

          <label className="block text-sm font-medium mb-1 text-gray-700">Monument Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
          />

          <label className="block text-sm font-medium mb-1 text-gray-700">City</label>
          <input
            type="text"
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="e.g. Lucknow"
            className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
          />

          <label className="block text-sm font-medium mb-1 text-gray-700">Description</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
          />

          <label className="block text-sm font-medium mb-1 text-gray-700">QR Code</label>
          <input
            type="text"
            value={qrCodeInput}
            onChange={(e) => setQrCodeInput(e.target.value)}
            className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
          />

          <div className="flex gap-3 mb-3">
            <div className="flex-1">
              <label className="block text-sm font-medium mb-1 text-gray-700">Latitude</label>
              <input
                type="text"
                value={lat}
                onChange={(e) => setLat(e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
              />
            </div>
            <div className="flex-1">
              <label className="block text-sm font-medium mb-1 text-gray-700">Longitude</label>
              <input
                type="text"
                value={lng}
                onChange={(e) => setLng(e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
              />
            </div>
          </div>

          <label className="block text-sm font-medium mb-1 text-gray-700">XP</label>
          <input
            type="number"
            value={xp}
            onChange={(e) => setXp(e.target.value)}
            className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-4 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
          />

          <button
            onClick={handleCreateQuest}
            disabled={loading}
            className="w-full bg-emerald-700 text-white py-3 rounded-lg font-medium hover:bg-emerald-800 transition disabled:opacity-60"
          >
            {loading ? "Creating..." : "Create Quest"}
          </button>

          {error && <p className="text-red-600 text-sm mt-3 break-words">{error}</p>}
        </div>
      )}

      {step === "questions" && (
        <div className="bg-white p-8 rounded-2xl shadow-lg shadow-emerald-900/5 border border-amber-100 w-full max-w-lg">
          <div className="flex items-center gap-2 mb-4 text-emerald-700">
            <HelpCircle size={22} />
            <span className="font-semibold">Quiz Questions ({questions.length})</span>
          </div>

          {questions.map((q, qIndex) => (
            <div key={qIndex} className="mb-5 pb-5 border-b border-gray-100 last:border-0">
              <div className="flex items-center justify-between mb-1">
                <label className="block text-sm font-medium text-gray-700">
                  Question {qIndex + 1}
                </label>
                {questions.length > 1 && (
                  <button
                    onClick={() => removeQuestion(qIndex)}
                    className="text-red-500 hover:text-red-700"
                    type="button"
                  >
                    <Trash2 size={16} />
                  </button>
                )}
              </div>
              <input
                type="text"
                value={q.question}
                onChange={(e) => updateQuestionText(qIndex, e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-4 py-2 mb-2 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
              />

              {q.options.map((opt, optIndex) => (
                <div key={optIndex} className="flex items-center gap-2 mb-2">
                  <input
                    type="radio"
                    name={`correct-${qIndex}`}
                    checked={q.correct_option === opt && opt !== ""}
                    onChange={() => updateCorrectOption(qIndex, opt)}
                    disabled={!opt}
                  />
                  <input
                    type="text"
                    placeholder={`Option ${optIndex + 1}`}
                    value={opt}
                    onChange={(e) => updateOption(qIndex, optIndex, e.target.value)}
                    className="flex-1 border border-gray-200 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
                  />
                </div>
              ))}
              <p className="text-xs text-gray-400">Select the radio button next to the correct option.</p>
            </div>
          ))}

          <button
            onClick={addQuestion}
            type="button"
            className="w-full flex items-center justify-center gap-2 border border-emerald-300 text-emerald-700 py-2.5 rounded-lg font-medium hover:bg-emerald-50 transition mb-4"
          >
            <Plus size={18} /> Add Another Question
          </button>

          <button
            onClick={handleSubmitQuestions}
            disabled={loading}
            className="w-full bg-emerald-700 text-white py-3 rounded-lg font-medium hover:bg-emerald-800 transition disabled:opacity-60"
          >
            {loading ? "Saving..." : "Submit Questions"}
          </button>

          {error && <p className="text-red-600 text-sm mt-3 break-words">{error}</p>}
        </div>
      )}

      {step === "done" && (
        <div className="bg-white p-6 rounded-2xl shadow-lg shadow-emerald-900/5 border border-amber-100 flex flex-col items-center w-full max-w-md">
          <p className="font-semibold text-gray-800 text-center">
            {name} added successfully.
          </p>
        </div>
      )}
    </div>
  );
}

export default MonumentSeeder;