.pragma library

// Resolving a reference found in a web page (an image src, a link href)
// against the page's URL, after RFC 3986 §5.2: protocol-relative takes the
// page's scheme, root-relative its origin, query-only its path, and dot
// segments in the merged path are removed. Returns "" when base is not an
// http(s) URL.

function parts(url) {
  var m = /^([a-z][a-z0-9+.-]*:)(\/\/[^/?#]*)?([^?#]*)(\?[^#]*)?(#.*)?$/i.exec(url)
  return m ? { scheme: m[1], authority: m[2] || "", path: m[3] || "", query: m[4] || "", hash: m[5] || "" } : null
}

// "/a/b/../c/./d" -> "/a/c/d"; never climbs above the root.
function removeDots(path) {
  var out = []
  var segs = path.split("/")
  for (var i = 0; i < segs.length; i++) {
    var s = segs[i], last = i === segs.length - 1
    if (s === ".") { if (last) out.push("") }
    else if (s === "..") { if (out.length > 1) out.pop(); if (last) out.push("") }
    else out.push(s)
  }
  var r = out.join("/")
  return path.charAt(0) === "/" && r.charAt(0) !== "/" ? "/" + r : r
}

function resolve(base, ref) {
  var b = parts(String(base || ""))
  if (!b || !/^https?:$/i.test(b.scheme)) return ""
  var r = String(ref || "")
  if (/^[a-z][a-z0-9+.-]*:/i.test(r)) return r
  var origin = b.scheme + b.authority
  if (r.indexOf("//") === 0) return b.scheme + r
  if (r === "") return origin + b.path + b.query
  if (r.charAt(0) === "#") return origin + b.path + b.query + r
  if (r.charAt(0) === "?") return origin + b.path + r
  // Split off the reference's own query and fragment; only the path merges.
  var cut = r.search(/[?#]/)
  var rpath = cut >= 0 ? r.slice(0, cut) : r, rest = cut >= 0 ? r.slice(cut) : ""
  var merged = rpath.charAt(0) === "/" ? rpath
             : (b.path === "" ? "/" : b.path.replace(/[^/]*$/, "")) + rpath
  return origin + removeDots(merged) + rest
}
