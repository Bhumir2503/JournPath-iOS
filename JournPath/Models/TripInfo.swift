import FirebaseFirestore
import Foundation
import SwiftUI

/// Single source of truth for a trip's appearance.
/// Icon and color live together on one enum case, so they can never drift out of sync.
/// Declaration order = matching priority (first match wins).
enum TripCategory: String, Codable, CaseIterable, Identifiable {
    case beach, surfing, mountains, winter, city, romance, roadTrip, flight, water
    case event, food, culture, business, gaming, sports, family, wellness
    case photography, music, camping, desert, safari, space, train, backpacking
    case shopping, graduation, birthday, friends, bachelor, cruise, cycling
    case running, diving, stargazing, luxury, adventure
    case generic

    var id: String { rawValue }

    // MARK: - Appearance

    var icon: String {
        switch self {
        case .beach: "beach.umbrella.fill"
        case .surfing: "figure.surfing"
        case .mountains: "mountain.2.fill"
        case .winter: "snowflake"
        case .city: "building.2.fill"
        case .romance: "heart.fill"
        case .roadTrip: "car.fill"
        case .flight: "airplane"
        case .water: "water.waves"
        case .event: "ticket.fill"
        case .food: "fork.knife"
        case .culture: "building.columns.fill"
        case .business: "briefcase.fill"
        case .gaming: "gamecontroller.fill"
        case .sports: "trophy.fill"
        case .family: "house.fill"
        case .wellness: "sparkles"
        case .photography: "camera.fill"
        case .music: "music.note"
        case .camping: "tent.fill"
        case .desert: "sun.max.fill"
        case .safari: "pawprint.fill"
        case .space: "lightbulb.fill"
        case .train: "tram.fill"
        case .backpacking: "backpack.fill"
        case .shopping: "bag.fill"
        case .graduation: "graduationcap.fill"
        case .birthday: "birthday.cake.fill"
        case .friends: "person.3.fill"
        case .bachelor: "wineglass.fill"
        case .cruise: "ferry.fill"
        case .cycling: "bicycle"
        case .running: "figure.run"
        case .diving: "drop.fill"
        case .stargazing: "moon.stars.fill"
        case .luxury: "crown.fill"
        case .adventure: "compass.drawing"
        case .generic: "map.fill"
        }
    }

    var color: Color {
        switch self {
        case .beach, .surfing, .water, .cruise, .diving: .cyan
        case .mountains, .camping: .green
        case .winter: .teal
        case .city, .business, .train: .secondary
        case .romance, .birthday, .shopping: .pink
        case .roadTrip: .red
        case .flight, .adventure, .generic: .blue
        case .event, .music, .gaming: .purple
        case .food, .desert, .friends, .bachelor: .orange
        case .culture, .wellness, .space, .luxury: .yellow
        case .safari, .backpacking: .brown
        case .sports, .cycling, .running: .mint
        case .family, .graduation, .stargazing: .indigo
        case .photography: .gray
        }
    }

    /// Human-readable name for pickers.
    var displayName: String {
        switch self {
        case .roadTrip: "Road Trip"
        case .generic: "Other"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    // MARK: - Keywords

    /// Keywords used for auto-suggestion from the trip name.
    /// Keywords of 3 characters or fewer are matched as whole words
    /// (so "spa" won't match "Spain", and "la" won't match "Atlanta").
    var keywords: [String] {
        switch self {
        case .beach:
            [
                "beach", "ocean", "sea", "shore", "coast", "island", "tropical",
                "hawaii", "bahamas", "maldives", "cancun", "bali", "caribbean",
                "resort", "lagoon", "reef", "waves", "vacation",
            ]
        case .surfing:
            ["surf", "surfing"]
        case .mountains:
            [
                "mountain", "hike", "hiking", "trail", "trek", "camp", "backpacking",
                "forest", "woods", "yosemite", "zion", "rockies", "alps", "nature",
                "national park", "outdoors", "wild",
            ]
        case .winter:
            [
                "ski", "skiing", "snow", "snowboard", "winter", "ice", "aspen",
                "whistler", "chalet", "cabin", "glacier", "arctic",
            ]
        case .city:
            [
                "city", "nyc", "new york", "tokyo", "paris", "london", "dubai",
                "vegas", "miami", "chicago", "los angeles", "la", "berlin",
                "downtown", "metro", "urban",
            ]
        case .romance:
            [
                "honeymoon", "wedding", "anniversary", "proposal", "date", "love",
                "romantic", "valentine",
            ]
        case .roadTrip:
            [
                "road", "drive", "highway", "route", "rv", "camper", "van",
                "cross country",
            ]
        case .flight:
            [
                "flight", "fly", "flying", "airport", "plane", "international",
                "abroad", "europe", "asia", "africa", "overseas",
            ]
        case .water:
            [
                "lake", "river", "boat", "kayak", "canoe", "rafting", "fishing",
                "sailing", "marina",
            ]
        case .event:
            [
                "disney", "universal", "concert", "festival", "coachella", "show",
                "fair", "expo", "event",
            ]
        case .food:
            [
                "food", "restaurant", "wine", "vineyard", "brewery", "beer",
                "dining", "bbq", "coffee", "cafe",
            ]
        case .culture:
            [
                "museum", "history", "culture", "castle", "ruins", "rome",
                "greece", "egypt", "temple", "historic",
            ]
        case .business:
            [
                "business", "conference", "work", "meeting", "summit", "office",
                "client",
            ]
        case .gaming:
            ["gaming", "esports", "xbox", "playstation"]
        case .sports:
            [
                "game", "football", "soccer", "baseball", "basketball", "race",
                "marathon", "golf", "tournament",
            ]
        case .family:
            [
                "family", "mom", "dad", "parents", "grandma", "grandpa",
                "grandparents", "reunion", "christmas", "thanksgiving", "home",
            ]
        case .wellness:
            ["spa", "wellness", "yoga", "retreat", "relax", "meditation"]
        case .photography:
            ["photo", "photography", "camera", "pictures"]
        case .music:
            ["music", "band", "guitar", "edm", "dj"]
        case .camping:
            ["tent", "campfire", "survival", "glamping"]
        case .desert:
            ["desert", "sahara", "dunes", "arizona"]
        case .safari:
            ["safari", "wildlife", "animals"]
        case .space:
            ["space", "nasa", "rocket", "science"]
        case .train:
            ["train", "rail", "subway"]
        case .backpacking:
            ["backpack", "hostel", "budget"]
        case .shopping:
            ["shopping", "mall", "outlets", "fashion"]
        case .graduation:
            ["graduation", "grad", "college", "school", "university"]
        case .birthday:
            ["birthday", "bday", "party"]
        case .friends:
            ["friends", "boys trip", "girls trip", "bros", "squad"]
        case .bachelor:
            ["bachelor", "bachelorette"]
        case .cruise:
            ["cruise", "ship", "ferry"]
        case .cycling:
            ["bike", "biking", "cycling", "bicycle"]
        case .running:
            ["run", "running", "jog", "jogging"]
        case .diving:
            ["dive", "diving", "scuba", "snorkel"]
        case .stargazing:
            ["stars", "stargazing", "astronomy"]
        case .luxury:
            ["luxury", "vip", "elite"]
        case .adventure:
            ["adventure", "explore", "expedition"]
        case .generic:
            []
        }
    }

    // MARK: - Matching

    /// Cache so repeated SwiftUI re-renders don't rescan the same name.
    private static var matchCache: [String: TripCategory] = [:]

    /// Suggests a category from a trip name. First declared match wins.
    static func match(_ name: String) -> TripCategory {
        if let cached = matchCache[name] { return cached }

        let lower = name.lowercased()
        // Split into words for whole-word matching of short keywords.
        let words = Set(
            lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )

        var result: TripCategory = .generic
        outer: for category in allCases where category != .generic {
            for keyword in category.keywords {
                let matched: Bool
                if keyword.count <= 3 && !keyword.contains(" ") {
                    matched = words.contains(keyword)  // whole-word only
                } else {
                    matched = lower.contains(keyword)  // substring
                }
                if matched {
                    result = category
                    break outer
                }
            }
        }

        matchCache[name] = result
        return result
    }

    // MARK: - Codable (safe against unknown values)

    /// If Firestore ever contains a category this app version doesn't know
    /// (e.g. added in a newer release), fall back to .generic instead of
    /// failing to decode the whole trip.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TripCategory(rawValue: raw) ?? .generic
    }
}

struct TripInfo: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let name: String
    let tier: Int
    let startDate: Date
    let endDate: Date
    let createdAt: Date?
    let role: String?

    /// User-chosen category. `nil` means "auto" — suggest one from the name.
    /// Optional, so every existing Firestore document decodes without migration.
    var category: TripCategory?

    var isPremium: Bool { tier >= 1 }

    // MARK: - Appearance

    /// The category actually used for display: the user's explicit choice,
    /// or an auto-suggestion from the trip name.
    var resolvedCategory: TripCategory {
        category ?? .match(name)
    }

    var icon: String { resolvedCategory.icon }
    var iconColor: Color { resolvedCategory.color }

    // MARK: - Drop-in compatibility with existing views
    // Existing code using trip.dynamicIcon / trip.dynamicIconColor keeps compiling.
    // Migrate call sites to `icon` / `iconColor` at your leisure, then delete these.

    var dynamicIcon: String { icon }
    var dynamicIconColor: Color { iconColor }
}
