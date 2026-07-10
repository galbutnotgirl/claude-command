import Foundation

public func mergeDictionaryValues(current: [String: Any], incoming: [String: Any]) -> [String: Any] {
    var merged = current
    for (key, value) in incoming { merged[key] = value }
    return merged
}

public func mergeDictionaryArrays(current: [[String: Any]], incoming: [[String: Any]], key: String) -> [[String: Any]] {
    var byKey: [String: [String: Any]] = [:]
    var order: [String] = []
    for item in current + incoming {
        let id = item[key] as? String ?? UUID().uuidString
        if byKey[id] == nil { order.append(id) }
        byKey[id] = item
    }
    return order.compactMap { byKey[$0] }
}

public func mergeEnrichRuleDictionaries(current: [[String: Any]], incoming: [[String: Any]]) -> [[String: Any]] {
    func ruleKey(_ item: [String: Any]) -> String {
        let match = item["match"] as? String ?? ""
        let pattern = item["pattern"] as? String ?? ""
        let pathPrefix = item["pathPrefix"] as? String ?? ""
        return "\(match)\u{1F}\(pattern)\u{1F}\(pathPrefix)"
    }

    var byKey: [String: [String: Any]] = [:]
    var order: [String] = []
    for item in current + incoming {
        let id = ruleKey(item)
        if byKey[id] == nil { order.append(id) }
        byKey[id] = item
    }
    return order.compactMap { byKey[$0] }
}

public func mergeVocabularyDictionaries(current: [String: Any], incoming: [String: Any]) -> [String: Any] {
    var merged = current
    merged["replacements"] = mergeDictionaryArrays(
        current: current["replacements"] as? [[String: Any]] ?? [],
        incoming: incoming["replacements"] as? [[String: Any]] ?? [],
        key: "wrong"
    )
    let vocab = Set((current["vocab"] as? [String] ?? []) + (incoming["vocab"] as? [String] ?? []))
    merged["vocab"] = Array(vocab).sorted()
    merged["fillers"] = mergeDictionaryArrays(
        current: current["fillers"] as? [[String: Any]] ?? [],
        incoming: incoming["fillers"] as? [[String: Any]] ?? [],
        key: "phrase"
    )
    return merged
}
