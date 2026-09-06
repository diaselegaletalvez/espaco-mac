import Foundation
import Darwin

enum Scanner {

    private static let volInfo: attrgroup_t      = 0x8000_0000
    private static let volSpaceUsed: attrgroup_t = 0x0080_0000

    static func spaceUsed(at path: String) -> Int64? {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.volattr = volInfo | volSpaceUsed

        var buf = [UInt8](repeating: 0, count: 64)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            getattrlist(path, &list, raw.baseAddress, raw.count, 0) == 0
        }
        guard ok else { return nil }

        let value = buf.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 4, as: UInt64.self)
        }
        return Int64(bitPattern: value)
    }

    static func disk() -> DiskInfo {
        let path = "/System/Volumes/Data"

        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return DiskInfo() }

        let bs = Int64(fs.f_bsize)
        let total = Int64(fs.f_blocks) * bs
        let avail = Int64(fs.f_bavail) * bs
        let used = spaceUsed(at: path) ?? (total - Int64(fs.f_bfree) * bs)

        return DiskInfo(total: total, available: avail, used: used)
    }

    static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey,
                                         .fileAllocatedSizeKey,
                                         .isRegularFileKey]

        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: keys)
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }

        guard let en = fm.enumerator(at: url,
                                     includingPropertiesForKeys: Array(keys),
                                     options: [],
                                     errorHandler: { _, _ in true }) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in en {
            guard let v = try? child.resourceValues(forKeys: keys),
                  v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    static func nodeModules(under root: URL) -> [URL] {
        let fm = FileManager.default
        var found: [URL] = []
        guard let projetos = try? fm.contentsOfDirectory(at: root,
                                                         includingPropertiesForKeys: [.isDirectoryKey],
                                                         options: [.skipsHiddenFiles]) else { return [] }
        for proj in projetos {
            let direct = proj.appending(path: "node_modules")
            if fm.fileExists(atPath: direct.path) { found.append(direct) }

            if let subs = try? fm.contentsOfDirectory(at: proj,
                                                      includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles]) {
                for sub in subs {
                    let nested = sub.appending(path: "node_modules")
                    if fm.fileExists(atPath: nested.path) { found.append(nested) }
                }
            }
        }
        return found
    }

    static func measure(_ target: Target) -> Int64 {
        if target.id == "nodemodules" {
            guard let root = target.paths.first else { return 0 }
            return nodeModules(under: root).reduce(0) { $0 + size(of: $1) }
        }
        return target.paths.reduce(0) { $0 + size(of: $1) }
    }
}
