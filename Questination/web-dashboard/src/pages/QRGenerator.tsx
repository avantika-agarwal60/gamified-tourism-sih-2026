import { useState } from "react";
import { QRCodeCanvas } from "qrcode.react";

function QRGenerator() {
  const [monumentName, setMonumentName] = useState("");
  const [checkpoint, setCheckpoint] = useState("");
  const [generatedValue, setGeneratedValue] = useState("");

  function handleGenerate() {
    if (monumentName && checkpoint) {
      const value = `site=${monumentName.replace(/\s/g, "-")}&checkpoint=${checkpoint.replace(/\s/g, "-")}`;
      setGeneratedValue(value);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 flex justify-center pt-12">
      <div className="w-96">
        <h1 className="text-2xl font-bold mb-4">Generate Quest QR Code</h1>

        <div className="bg-white p-6 rounded-lg shadow mb-6">
          <label className="block text-sm font-medium mb-1">Monument Name</label>
          <input
            type="text"
            value={monumentName}
            onChange={(e) => setMonumentName(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2 mb-3"
          />

          <label className="block text-sm font-medium mb-1">Checkpoint Name</label>
          <input
            type="text"
            placeholder="e.g. Main Gate"
            value={checkpoint}
            onChange={(e) => setCheckpoint(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2 mb-4"
          />

          <button
            onClick={handleGenerate}
            className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700"
          >
            Generate QR Code
          </button>
        </div>

        {generatedValue && (
          <div className="bg-white p-6 rounded-lg shadow flex flex-col items-center">
            <QRCodeCanvas value={generatedValue} size={200} />
            <p className="text-sm text-gray-500 mt-3 break-all">{generatedValue}</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default QRGenerator;