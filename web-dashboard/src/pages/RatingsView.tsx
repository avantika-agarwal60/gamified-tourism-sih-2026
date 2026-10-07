// Fake/mock rating data (pretend this came from the backend later)
import { Star } from "lucide-react";
import PageHeader from "../components/PageHeader";

const mockRatings = [
  { id: 1, name: "Riya S.", stars: 5, comment: "Loved the handicrafts, great discount!" },
  { id: 2, name: "Amit K.", stars: 4, comment: "Good quality, quick redemption." },
  { id: 3, name: "Priya M.", stars: 5, comment: "Friendly shop owner, will visit again." },
];

function RatingsView() {
  return (
    <div>
      <PageHeader title="Customer Ratings" subtitle="See what tourists are saying about your shop." />
      <div className="w-full max-w-md flex flex-col gap-3">
        {mockRatings.map((rating) => (
          <div
            key={rating.id}
            className="bg-white p-4 rounded-2xl shadow-lg shadow-emerald-900/5 border border-amber-100"
          >
            <div className="flex justify-between items-center mb-1">
              <span className="font-semibold text-gray-800">{rating.name}</span>
              <span className="flex gap-0.5 text-amber-500">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Star key={i} size={15} fill={i < rating.stars ? "currentColor" : "none"} />
                ))}
              </span>
            </div>
            <p className="text-gray-500 text-sm">{rating.comment}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default RatingsView;