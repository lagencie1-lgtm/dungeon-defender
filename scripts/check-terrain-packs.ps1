param([Parameter(Mandatory)][string]$PlaceFile)
$ErrorActionPreference = "Stop"

# Studio can preview the source maps even when the player-ready pack is missing.
# Check the exact place file that Open Cloud will receive.
$place = New-Object System.Xml.XmlDocument
$place.Load((Resolve-Path -LiteralPath $PlaceFile).Path)
$materials = $place.SelectNodes("//Item[@class='MaterialService']/Item[@class='MaterialVariant']")
$sources = @(Get-ChildItem "$PSScriptRoot/../src/materials/*.model.json")
if ($sources.Count -eq 0 -or $materials.Count -ne $sources.Count) {
    throw "The release has $($materials.Count) terrain variants for $($sources.Count) source files."
}
foreach ($source in $sources) {
    $name = $source.Name -replace '\.model\.json$', ''
    $spec = (Get-Content -Raw -LiteralPath $source.FullName | ConvertFrom-Json).properties
    $properties = $place.SelectSingleNode("//Item[@class='MaterialService']/Item[@class='MaterialVariant']/Properties[string[@name='Name']='$name']")
    if (!$properties) { throw "Missing terrain variant $name in the release." }
    foreach ($field in 'ColorMap','RoughnessMap','TexturePack') {
        $uri = $properties.SelectSingleNode("Content[@name='${field}Content']/uri")
        if (!$uri -or $uri.InnerText -notmatch '^rbxassetid://[1-9][0-9]*$' -or $uri.InnerText -ne $spec.$field) {
            throw "Missing or mismatched $field for $name in the release."
        }
    }
}
Write-Output "Verified painted textures and baked packs for $($materials.Count) terrain materials."
