import Foundation

internal extension String {
    // Source: https://datatracker.ietf.org/doc/html/rfc3986#section-3.3
    // i.e. segment = unreserved / pct-encoded / sub-delims / ":" / "@", where
    //  unreserved = ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~
    //  pct-encoded = %XX
    //  sub-delims = !$&'()*+,;=
    func encodePathSegment() -> String {
        let allowedSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$&'()*+,;=:@")
        guard let escaped = addingPercentEncoding(withAllowedCharacters: allowedSet) else {
            fatalError("String '\(self)' can't be percent encoded.")
        }
        return escaped
    }
}
