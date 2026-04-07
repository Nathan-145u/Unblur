//
//  RSSParser.swift
//  Unblur
//

import Foundation

struct ParsedEpisode {
    var title: String
    var publishDate: Date
    var duration: TimeInterval
    var remoteAudioURL: String
    var artworkURL: String?
}

struct ParsedFeed {
    var channelArtworkURL: String?
    var episodes: [ParsedEpisode]
}

enum RSSParserError: Error {
    case network(Error)
    case parse
    case noData
}

final class RSSParser: NSObject, XMLParserDelegate {
    static let feedURL = URL(string: "https://feeds.megaphone.fm/STHZE1330487576")!

    private var currentElement = ""
    private var currentText = ""
    private var insideItem = false
    private var inImage = false

    private var channelArtworkURL: String?
    private var currentTitle = ""
    private var currentPubDate = ""
    private var currentDuration: TimeInterval = 0
    private var currentEnclosureURL = ""
    private var currentItemImage: String?
    private var episodes: [ParsedEpisode] = []

    static func fetch() async throws -> ParsedFeed {
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            return try parse(data: data)
        } catch let e as RSSParserError {
            throw e
        } catch {
            throw RSSParserError.network(error)
        }
    }

    static func parse(data: Data) throws -> ParsedFeed {
        let p = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = p
        guard xml.parse() else { throw RSSParserError.parse }
        return ParsedFeed(channelArtworkURL: p.channelArtworkURL, episodes: p.episodes)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentPubDate = ""
            currentDuration = 0
            currentEnclosureURL = ""
            currentItemImage = nil
        } else if elementName == "image" {
            inImage = true
        } else if elementName == "enclosure", insideItem {
            if let url = attributeDict["url"] {
                currentEnclosureURL = url
            }
        } else if elementName == "itunes:image" {
            if let href = attributeDict["href"] {
                if insideItem {
                    currentItemImage = href
                } else if channelArtworkURL == nil {
                    channelArtworkURL = href
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideItem {
            switch elementName {
            case "title":
                if currentTitle.isEmpty { currentTitle = trimmed }
            case "pubDate":
                currentPubDate = trimmed
            case "itunes:duration":
                currentDuration = Self.parseDuration(trimmed)
            case "item":
                let date = AppFormatters.rss.date(from: currentPubDate) ?? Date()
                if !currentEnclosureURL.isEmpty {
                    episodes.append(ParsedEpisode(
                        title: currentTitle,
                        publishDate: date,
                        duration: currentDuration,
                        remoteAudioURL: currentEnclosureURL,
                        artworkURL: currentItemImage ?? channelArtworkURL
                    ))
                }
                insideItem = false
            default:
                break
            }
        } else if inImage {
            if elementName == "url", channelArtworkURL == nil {
                channelArtworkURL = trimmed
            } else if elementName == "image" {
                inImage = false
            }
        }
    }

    static func parseDuration(_ s: String) -> TimeInterval {
        // Accepts HH:MM:SS, MM:SS, or seconds.
        let parts = s.split(separator: ":").map { Double($0) ?? 0 }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }
}
