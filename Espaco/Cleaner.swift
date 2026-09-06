import Foundation

struct CleanResult: Sendable {
    var freed: Int64 = 0
    var itemsRemoved: Int = 0
    var itemsTrashed: Int = 0
    var failures: [String] = []

    var isEmpty: Bool { itemsRemoved == 0 && itemsTrashed == 0 && failures.isEmpty }
}

enum Cleaner {

    static func targetsPaths(_ target: Target) -> [URL] {
        let fm = FileManager.default
        if target.id == "nodemodules" {
            guard let root = target.paths.first else { return [] }
            return Scanner.nodeModules(under: root)
        }
        return target.paths.filter { fm.fileExists(atPath: $0.path) }
    }

    static func clean(_ target: Target) -> CleanResult {
        var result = CleanResult()
        let fm = FileManager.default
        let goesToTrash = target.risk != .zero

        for url in targetsPaths(target) {
            let sizeBefore = Scanner.size(of: url)
            let removeWhole = target.id == "nodemodules"

            do {
                if removeWhole {
                    if goesToTrash {
                        var out: NSURL?
                        try fm.trashItem(at: url, resultingItemURL: &out)
                        result.itemsTrashed += 1
                    } else {
                        try fm.removeItem(at: url)
                        result.itemsRemoved += 1
                    }
                } else {
                    let children = (try? fm.contentsOfDirectory(at: url,
                                                                includingPropertiesForKeys: nil,
                                                                options: [])) ?? []
                    if children.isEmpty {
                        if fm.fileExists(atPath: url.path),
                           (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true {
                            try fm.removeItem(at: url)
                            result.itemsRemoved += 1
                        }
                    }
                    for child in children {
                        if goesToTrash {
                            var out: NSURL?
                            try fm.trashItem(at: child, resultingItemURL: &out)
                            result.itemsTrashed += 1
                        } else {
                            try fm.removeItem(at: child)
                            result.itemsRemoved += 1
                        }
                    }
                }
                result.freed += sizeBefore
            } catch {
                result.failures.append(url.lastPathComponent)
            }
        }
        return result
    }
}
