function sf-seed-DynamicTypes {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$moduleName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$moduleNameSingular
    )
    
    $res = sf-wcf-invoke -path "Sitefinity/Services/DynamicModules/ContentTypeService.svc/checkModuleName/?moduleName=$moduleName" | ConvertFrom-Json
    if ($res.IsContained) {
        throw "Module already exists."
    }

    $res = sf-wcf-invoke -path "Sitefinity/Services/DynamicModules/ContentTypeService.svc/00000000-0000-0000-0000-000000000000/" -method "PUT" -body "{`"ContentTypeName`":`"$moduleName`",`"ContentTypeDescription`":`"`",`"ContentTypeItemTitle`":`"$moduleNameSingular`",`"ContentTypeItemName`":`"$moduleNameSingular`",`"ContentTypeTitle`":`"$moduleName`",`"Fields`":[{`"AllowImageLibrary`":false,`"AllowMultipleFiles`":false,`"AllowMultipleImages`":false,`"AllowMultipleVideos`":false,`"AllowNulls`":false,`"CanCreateItemsWhileSelecting`":true,`"CanSelectMultipleItems`":true,`"CheckedByDefault`":false,`"ChoiceRenderType`":`"RadioButton`",`"Choices`":`"`",`"ClassificationId`":`"d7831091-e7b1-41b8-9e75-dff32d6a7837`",`"ColumnName`":`"`",`"DBLength`":`"`",`"DBType`":`"VARCHAR`",`"DecimalPlacesCount`":0,`"DefaultValue`":`"`",`"FileExtensions`":`"`",`"FileMaxSize`":0,`"ImageExtensions`":`"`",`"ImageMaxSize`":0,`"IncludeInIndexes`":false,`"InstructionalChoice`":`"- Select -`",`"InstructionalText`":`"`",`"IsHiddenField`":false,`"IsRequired`":true,`"IsRequiredToSelectCheckbox`":false,`"IsRequiredToSelectDdlValue`":false,`"LengthValidationMessage`":`"`",`"MaxLength`":0,`"MediaType`":`"`",`"MinLength`":0,`"Name`":`"Title`",`"NumberUnit`":`"`",`"RegularExpression`":null,`"Title`":`"Title`",`"TypeName`":`"ShortText`",`"TypeUIName`":`"Short text`",`"VideoExtensions`":`"`",`"VideoMaxSize`":0,`"WidgetTypeName`":`"Telerik.Sitefinity.Web.UI.Fields.TextField`",`"IsLocalizable`":true}],`"MainShortTextFieldName`":`"Title`",`"IsSelfReferencing`":false,`"CheckFieldPermissions`":false}"

    $moduleId = ($res.Content | ConvertFrom-Json).ModuleId
    sf-wcf-invoke -path "Sitefinity/Services/DynamicModules/ContentTypeService.svc/activate/" -method "POST" -body "`"$moduleId`""
}
