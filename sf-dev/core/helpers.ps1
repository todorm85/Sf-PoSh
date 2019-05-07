function _select-item($items) {
    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $item = $items[$choice]
        if ($null -ne $item) {
            return $item
        }
    }
}
