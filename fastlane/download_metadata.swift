#!/usr/bin/env swift

import Foundation

let glotPressTitleKey = "app_store_title"
let glotPressSubtitleKey = "app_store_subtitle"
let glotPressWhatsNewKey = "v4.43-whats-new"
let glotPressDescriptionKey = "app_store_desc"
let glotPressKeywordsKey = "app_store_keywords"

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let fastlaneDir = scriptURL.deletingLastPathComponent()
let baseFolder = fastlaneDir.appendingPathComponent("metadata").path

// iTunes Connect language code: GlotPress code
let languages = [
    "ar-SA": "ar",
    "de-DE": "de",
    "default": "en-us", // Technically not a real GlotPress language
    "en-US": "en-us", // Technically not a real GlotPress language
    "es-ES": "es",
    "fr-FR": "fr",
    "id": "id",
    "it": "it",
    "ja": "ja",
    "ko": "ko",
    "nl-NL": "nl",
    "pt-BR": "pt-br",
    "ru": "ru",
    "sv": "sv",
    "tr": "tr",
    "zh-Hans": "zh-cn",
    "zh-Hant": "zh-tw",
]

func downloadTranslation(languageCode: String, folderName: String) {
    let languageCodeOverride = languageCode == "en-us" ? "es" : languageCode
    let glotPressURL = "https://translate.wordpress.com/projects/simplenote%2Fios%2Frelease-notes/\(languageCodeOverride)/default/export-translations?format=json"
    let requestURL: URL = URL(string: glotPressURL)!
    let urlRequest: URLRequest = URLRequest(url: requestURL)
    let session = URLSession.shared

    let sema = DispatchSemaphore( value: 0)

    print("Downloading Language: \(languageCode)")
	
    let task = session.dataTask(with: urlRequest) {
        (data, response, error) -> Void in

        defer {
            sema.signal()
        }

        guard let data = data else {
            print("  Invalid data downloaded.")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let jsonDict = json as? [String: Any] else {
                print("  JSON was not returned")
                return
        }

        var title: String?
        var subtitle: String?
        var whatsNew: String?
        var keywords: String?
        var storeDescription: String?

        jsonDict.forEach({ (key: String, value: Any) in

            guard let index = key.firstIndex(of: Character(UnicodeScalar(0004))) else {
            	return
            }

            let keyFirstPart = String(key[..<index])

            guard let value = value as? [String],
                let firstValue = value.first else {
                    print("  No translation for \(keyFirstPart)")
                    return
            }

            var originalLanguage = String(key[index...])
            originalLanguage.remove(at: originalLanguage.startIndex)
            let translation = languageCode == "en-us" ? originalLanguage : firstValue
            
            switch keyFirstPart {
            case glotPressTitleKey:
                title = translation
            case glotPressSubtitleKey:
                subtitle = translation
            case glotPressKeywordsKey:
                keywords = translation
            case glotPressWhatsNewKey:
                whatsNew = translation
            case glotPressDescriptionKey:
                storeDescription = translation
            default:
                print("  Unknown key: \(keyFirstPart)")
            }
        })

        let languageFolder = "\(baseFolder)/\(folderName)"

        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: languageFolder, withIntermediateDirectories: true, attributes: nil)

        do {
            try title?.write(toFile: "\(languageFolder)/name.txt", atomically: true, encoding: .utf8)
            try subtitle?.write(toFile: "\(languageFolder)/subtitle.txt", atomically: true, encoding: .utf8)
            try whatsNew?.write(toFile: "\(languageFolder)/release_notes.txt", atomically: true, encoding: .utf8)
            try keywords?.write(toFile: "\(languageFolder)/keywords.txt", atomically: true, encoding: .utf8)
            try storeDescription?.write(toFile: "\(languageFolder)/description.txt", atomically: true, encoding: .utf8)
        } catch {
            print("  Error writing: \(error)")
        }
    }
    
    task.resume()
    sema.wait()
}

func deleteExistingMetadata() {
    let fileManager = FileManager.default
	let url = URL(fileURLWithPath: baseFolder, isDirectory: true)
	try? fileManager.removeItem(at: url)	
	try? fileManager.createDirectory(at: url, withIntermediateDirectories: false)
}


deleteExistingMetadata()

languages.forEach( { (key: String, value: String) in
    downloadTranslation(languageCode: value, folderName: key)
})

