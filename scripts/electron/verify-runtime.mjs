const requiredCategories = [
  ['NSApplication', 'FTAutotrack'],
  ['NSWindow', 'FTAutoTrack'],
  ['WKWebView', 'FTAutoTrack'],
]

export function verifyObjectiveCCategories(objectiveCMetadata) {
  const symbols = new Set(objectiveCMetadata.split('\n').map((line) => line.trim().split(/\s+/u).at(-1)))
  const mergedCategories = new Set()
  for (const symbol of symbols) {
    // ld can merge categories of the same class, keeping only one category
    // record and naming the shared method list Class(CategoryA|CategoryB).
    const merged = symbol.match(/^__OBJC_\$_INSTANCE_METHODS_([^()]+)\(([^()]+)\)$/u)
    if (!merged) continue
    const [, className, names] = merged
    const categories = names.split('|')
    const categorySymbols = categories.map((name) => `__OBJC_$_CATEGORY_${className}_$_${name}`)
    if (categorySymbols.some((category) => symbols.has(category))) {
      for (const category of categorySymbols) mergedCategories.add(category)
    }
  }
  for (const [className, categoryName] of requiredCategories) {
    const category = `__OBJC_$_CATEGORY_${className}_$_${categoryName}`
    if (!symbols.has(category) && !mergedCategories.has(category)) {
      throw new Error(`Static Node-API addon is missing Objective-C Category: ${category}`)
    }
  }
}
