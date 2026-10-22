.pragma library

// Choosing the reading families. An embedder or the environment can ask
// for any family; a family that is not installed falls back to OmaRead's
// default rather than to whatever Qt would substitute.

// The installed spelling of `requested` when it is in `available` (case is
// ignored), otherwise `fallback`. An empty request is the fallback.
function pick(requested, available, fallback) {
  var r = String(requested || "").trim()
  if (!r) return fallback
  var list = available || []
  if (list.indexOf(r) >= 0) return r
  var lower = r.toLowerCase()
  for (var i = 0; i < list.length; i++)
    if (String(list[i]).toLowerCase() === lower) return list[i]
  return fallback
}

// "Family/Style" (the style is optional) -> { family, style }. A missing
// family falls back to the default family and the default style together,
// so a style asked for one family is never applied to another.
function pickStyled(requested, available, fallbackFamily, fallbackStyle) {
  var parts = String(requested || "").split("/")
  var family = pick(parts[0], available, "")
  if (!family) return { family: fallbackFamily, style: fallbackStyle }
  var style = (parts[1] || "").trim()
  return { family: family, style: style || fallbackStyle }
}
