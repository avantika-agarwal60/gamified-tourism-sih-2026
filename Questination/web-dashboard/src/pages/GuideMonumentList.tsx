const monuments = [
  { id: 1, name: "Bara Imambara", city: "Lucknow" },
  { id: 2, name: "Rumi Darwaza", city: "Lucknow" },
  { id: 3, name: "Chota Imambara", city: "Lucknow" },
];

function GuideMonumentList() {
  return (
    <div className="min-h-screen bg-gray-50 flex justify-center pt-12">
      <div className="w-96">
        <h1 className="text-2xl font-bold mb-4">ASI Monuments</h1>

        {monuments.map((m) => (
          <div key={m.id} className="bg-white p-4 rounded-lg shadow mb-3">
            <p className="font-semibold">{m.name}</p>
            <p className="text-sm text-gray-500">{m.city}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default GuideMonumentList;