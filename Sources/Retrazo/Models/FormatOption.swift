import Foundation

struct FormatOption: Codable, Identifiable, Hashable {
    var id: String { formatId }
    let formatId: String
    let ext: String
    let resolution: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let tbr: Double? // Total bitrate
    let vbr: Double? // Video bitrate
    let abr: Double? // Audio bitrate
    let formatNote: String?
    
    var isVideoOnly: Bool {
        (vcodec != nil && vcodec != "none") && (acodec == nil || acodec == "none")
    }
    
    var isAudioOnly: Bool {
        (acodec != nil && acodec != "none") && (vcodec == nil || vcodec == "none")
    }
    
    var isCombined: Bool {
        (vcodec != nil && vcodec != "none") && (acodec != nil && acodec != "none")
    }
    
    var displayTitle: String {
        var parts: [String] = []
        if let res = resolution, !res.isEmpty && res != "audio only" {
            parts.append(res)
        } else if let h = height {
            parts.append("\(h)p")
        }
        
        if let fps = fps, fps > 30 {
            parts.append("\(Int(fps))fps")
        }
        
        parts.append(ext.uppercased())
        
        if let note = formatNote, !note.isEmpty {
            parts.append("(\(note))")
        }
        
        if let size = formattedFileSize {
            parts.append("• \(size)")
        }
        
        return parts.joined(separator: " ")
    }
    
    var formattedFileSize: String? {
        let bytes = filesize ?? filesizeApprox
        guard let b = bytes, b > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}
