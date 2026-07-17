import FirebaseFirestore
import Foundation
import SwiftUI

struct TripInfo: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let name: String
    let tier: Int
    let startDate: Date
    let endDate: Date
    let createdAt: Date?
    let role: String?
    
    var isPremium: Bool { tier >= 1 }

    var dynamicIcon: String {
        let lowerName = name.lowercased()

        let iconMap: [(keywords: [String], icon: String)] = [
            (
                [
                    "beach", "ocean", "sea", "shore", "coast", "island", "tropical", "hawaii", "bahamas", "maldives", "cancun", "bali", "caribbean", "resort", "lagoon", "reef", "surf", "waves",
                    "vacation",
                ], "beach.umbrella.fill"
            ),
            (["mountain", "hike", "trail", "trek", "camp", "backpacking", "forest", "woods", "yosemite", "zion", "rockies", "alps", "nature", "national park", "outdoors", "wild"], "mountain.2.fill"),
            (["ski", "snow", "snowboard", "winter", "ice", "aspen", "whistler", "chalet", "cabin", "glacier", "arctic"], "snowflake"),
            (["city", "nyc", "new york", "tokyo", "paris", "london", "dubai", "vegas", "miami", "chicago", "los angeles", "la ", "berlin", "downtown", "metro", "urban"], "building.2.fill"),
            (["honeymoon", "wedding", "anniversary", "proposal", "date", "love", "romantic", "valentine"], "heart.fill"),
            (["road", "drive", "highway", "route", "rv", "camper", "van", "cross country"], "car.fill"),
            (["flight", "fly", "airport", "plane", "international", "abroad", "europe", "asia", "africa", "overseas"], "airplane"),
            (["lake", "river", "boat", "kayak", "canoe", "rafting", "fishing", "cruise", "sailing", "marina"], "water.waves"),
            (["disney", "universal", "concert", "festival", "coachella", "show", "fair", "expo", "event"], "ticket.fill"),
            (["food", "restaurant", "wine", "vineyard", "brewery", "beer", "dining", "bbq", "coffee", "cafe"], "fork.knife"),
            (["museum", "history", "culture", "castle", "ruins", "rome", "greece", "egypt", "temple", "historic"], "building.columns.fill"),
            (["business", "conference", "work", "meeting", "summit", "office", "client"], "briefcase.fill"),
            (["game", "football", "soccer", "baseball", "basketball", "race", "marathon", "golf", "tournament"], "trophy.fill"),
            (["family", "mom", "dad", "parents", "grandma", "grandpa", "reunion", "christmas", "thanksgiving", "home"], "house.fill"),
            (["spa", "wellness", "yoga", "retreat", "relax", "meditation"], "sparkles"),
            (["photo", "photography", "camera", "pictures"], "camera.fill"),
            (["music", "band", "guitar", "edm", "dj"], "music.note"),
            (["tent", "campfire", "survival"], "tent.fill"),
            (["desert", "sahara", "dunes", "arizona"], "sun.max.fill"),
            (["safari", "wildlife", "animals"], "pawprint.fill"),
            (["space", "nasa", "rocket", "science"], "lightbulb.fill"),
            (["train", "rail", "subway", "metro"], "tram.fill"),
            (["backpack", "hostel", "budget"], "backpack.fill"),
            (["shopping", "mall", "outlets", "fashion"], "bag.fill"),
            (["graduation", "college", "school", "university"], "graduationcap.fill"),
            (["birthday", "bday", "party"], "birthday.cake.fill"),
            (["friends", "boys trip", "girls trip", "bros"], "person.3.fill"),
            (["bachelor", "bachelorette"], "wineglass.fill"),
            (["gaming", "esports", "xbox", "playstation"], "gamecontroller.fill"),
            (["cruise", "ship"], "ferry.fill"),
            (["bike", "cycling", "bicycle"], "bicycle"),
            (["run", "jog"], "figure.run"),
            (["surf", "surfing"], "figure.surfing"),
            (["dive", "scuba"], "drop.fill"),
            (["stars", "stargazing", "astronomy"], "moon.stars.fill"),
            (["luxury", "vip", "elite"], "crown.fill"),
            (["adventure", "explore", "expedition"], "compass.drawing"),
        ]

        for mapping in iconMap {
            if mapping.keywords.contains(where: lowerName.contains) {
                return mapping.icon
            }
        }

        return "map.fill"
    }

    var dynamicIconColor: Color {
        let colorMap: [(icons: [String], color: Color)] = [
            (["beach.umbrella.fill", "water.waves", "ferry.fill", "sailboat.fill", "drop.fill"], .cyan),
            (["mountain.2.fill", "figure.hiking", "tree.fill", "leaf.fill", "tent.fill"], .green),
            (["snowflake", "snowflake.circle.fill", "figure.skiing.downhill"], .teal),
            (["building.2.fill", "briefcase.fill", "tram.fill", "tram.circle.fill"], .secondary),
            (["heart.fill", "heart.circle.fill"], .pink),
            (["car.fill", "road.lanes"], .red),
            (["airplane", "airplane.circle.fill", "passport.fill"], .blue),
            (["ticket.fill", "music.note", "music.mic", "guitars.fill"], .purple),
            (["fork.knife", "fork.knife.circle.fill", "wineglass.fill"], .orange),
            (["building.columns.fill", "crown.fill"], .yellow),
            (["suitcase.fill", "backpack.fill", "wallet.pass.fill", "luggagecart.fill"], .brown),
            (["trophy.fill", "trophy.circle.fill", "figure.run", "bicycle", "bicycle.circle.fill"], .mint),
            (["house.fill", "house.lodge.fill"], .indigo),
            (["sparkles", "sparkle.magnifyingglass", "lightbulb.fill"], .yellow),
            (["moon.stars.fill"], .indigo),
            (["sun.max.fill", "sunrise.fill", "sunset.fill"], .orange),
            (["camera.fill", "camera.aperture", "camera.macro"], .gray),
            (["birthday.cake.fill", "party.popper.fill"], .pink),
            (["map.fill", "compass.drawing", "location.fill", "mappin.and.ellipse", "binoculars.fill"], .blue),
        ]

        let currentIcon = dynamicIcon
        for mapping in colorMap {
            if mapping.icons.contains(currentIcon) {
                return mapping.color
            }
        }

        return .accentColor
    }
}
