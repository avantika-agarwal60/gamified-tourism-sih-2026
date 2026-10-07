import { useState } from "react";

function QuestSubmission() {
  const [monument, setMonument] = useState("");
  const [hint, setHint] = useState("");
  const [submitted, setSubmitted] = useState<string[]>([]);

  function handleSubmit() {
    if (monument && hint) {
      setSubmitted([...submitted, `${monument}: "${hint}"`]);
      setMonument("");
      setHint("");
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 flex justify-center pt-12">
      <div className="w-96">
        <h1 className="text-2xl font-bold mb-4">Submit Quest Pointer</h1>

        <div className="bg-white p-6 rounded-lg shadow mb-6">
          <label className="block text-sm font-medium mb-1">Monument Name</label>
          <input
            type="text"
            value={monument}
            onChange={(e) => setMonument(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2 mb-3"
          />

          <label className="block text-sm font-medium mb-1">Quest Hint / Pointer</label>
          <textarea
            placeholder="e.g. Look for the carving above the main arch..."
            value={hint}
            onChange={(e) => setHint(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2 mb-4"
            rows={3}
          />

          <button
            onClick={handleSubmit}
            className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700"
          >
            Submit Pointer
          </button>
        </div>

        {submitted.length > 0 && (
          <div>
            <h2 className="font-semibold mb-2">Submitted Pointers:</h2>
            {submitted.map((s, i) => (
              <p key={i} className="bg-white p-2 rounded shadow mb-2 text-sm">
                {s}
              </p>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default QuestSubmission;