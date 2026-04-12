-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---
-- @category Utils
Utils = {}


---Returns second parameter if the first is nil
-- @param any value value
-- @param any setTo set to value
-- @return any value not nil value
function Utils.getNoNil(value, setTo) end







---
-- @param float valueDeg
-- @param any defaultRad
-- @return float valueRad
function Utils.getNoNilRad(valueDeg, defaultRad) end







---
-- @param string text
-- @param float textSize
-- @param float width
-- @param boolean? trimFront default: false
-- @param string trimReplaceText
-- @return string text
-- @return integer indexOfFirstCharacter
-- @return integer indexOfLastCharacter
function Utils.limitTextToWidth(text, textSize, width, trimFront, trimReplaceText) end



















---
-- @param number curVal
-- @param number maxVal
-- @param number minVal
-- @param number speed
-- @param number dt
-- @param boolean inverted
-- @return number minVal
function Utils.getMovedLimitedValue(curVal, maxVal, minVal, speed, dt, inverted) end

















---
-- @param number currentValues
-- @param number maxValues
-- @param number minValues
-- @param number numValues
-- @param number speed
-- @param number dt
-- @param boolean inverted
-- @return number ret
function Utils.getMovedLimitedValues(currentValues, maxValues, minValues, numValues, speed, dt, inverted) end








---
-- @param number values
-- @param number maxValues
-- @param number minValues
-- @param number numValues
-- @param number speed
-- @param number dt
-- @param boolean inverted
-- @return number changed
function Utils.setMovedLimitedValues(values, maxValues, minValues, numValues, speed, dt, inverted) end

























































---Gets a unique id for the given value, ensuring there are no collisions with the given mapping table. Appends the given prefix to the start and truncates the md5 hash to the given length.
-- @param any value The value from which to make the unique id. Note that calling this function with the same value twice will give different ids.
-- @param table? mappingTable The optional table to check against for collisions. For each id that is generated, the table is checked. If the value with that key is anything other than nil; a new id is generated.
-- @param string? prefix The optional prefix to append to the front of the id.
-- @param integer? md5Length The optional length of the desired md5 hash, between 1 and 32. This length does not include the prefix. If this is nil, the full 32 characters will be used.
-- @return string uniqueId The generated unique id.
function Utils.getUniqueId(value, mappingTable, prefix, md5Length)

    -- Default the md5 length to nil if it is not valid.
    if type(md5Length) ~= "number" or md5Length <= 0 or md5Length >= 32 then
        md5Length = nil
    end

    --#debug Assert.isNotNil(value, "Mapping value cannot be nil!")
    --#debug Assert.isNilOrType(mappingTable, "table", "Mapping table must be a table or nil!")
    --#debug Assert.isNilOrType(prefix, "string", "Prefix must be a string or nil!")

    -- Default the prefix to an empty string.
    prefix = prefix or ""

    -- Keep generating unique ids until one is found that does not collide.
    local uniqueId
    local i = 0
    repeat
        local md5 = getMD5(tostring(value) .. tostring(getTime()) .. tostring(i))
        if md5Length ~= nil then
            uniqueId = prefix .. string.sub(md5, 1, md5Length)
        else
            uniqueId = prefix .. md5
        end
        i = i + 1
    until mappingTable == nil or mappingTable[uniqueId] == nil

    -- Return the unique id.
    return uniqueId
end

---
-- @param string filename
-- @return string modName
-- @return string baseDirectory
function Utils.getModNameAndBaseDirectory(filename) end





















---
-- @param entityId repr
-- @param entityId componentNode
-- @param number dt
-- @param number posX
-- @param number posY
-- @param number posZ
-- @param number currentAngle in radian
-- @param number minAngle in radian
-- @param number maxAngle in radian
-- @return number steeringAngle
function Utils.getVersatileRotation(repr, componentNode, dt, posX, posY, posZ, currentAngle, minAngle, maxAngle) end































---
-- @param entityId node1
-- @param entityId node2
-- @param number offset1 in radian
-- @param number offset2 in radian
-- @param boolean wrapRotation
-- @return number rotation
function Utils.getYRotationBetweenNodes(node1, node2, offset1, offset2, wrapRotation) end






























---
-- @param string profileClass
-- @return integer currentProfileIndex one of GS_PROFILE_*
function Utils.getPerformanceClassIndex(profileClass) end
























---
-- @param integer profileClassIndex
-- @return string currentProfileClass e.g. "Very High"
function Utils.getPerformanceClassFromIndex(profileClassIndex) end
















---
-- @return integer currentProfileIndex
function Utils.getPerformanceClassId() end




---
-- @param array values
-- @param number steps
-- @param number value
-- @return integer state
function Utils.getStateFromValues(values, steps, value) end











---
-- @param number targetValue
-- @param table values
-- @return integer index
function Utils.getValueIndex(targetValue, values) end














---
-- @return integer numSettings
function Utils.getNumTimeScales() end













---
-- @param integer timeScaleIndex
-- @return string formatedString
function Utils.getTimeScaleString(timeScaleIndex) end



















---
-- @param number timeScale
-- @return integer i
function Utils.getTimeScaleIndex(timeScale) end





















---
-- @param integer timeScaleIndex
-- @return number timeScale
function Utils.getTimeScaleFromIndex(timeScaleIndex) end















---
-- @param number masterVolume
-- @return integer masterVolumeIndex
function Utils.getMasterVolumeIndex(masterVolume) end



















---
-- @param integer masterVolumeIndex
-- @return number volume
function Utils.getMasterVolumeFromIndex(masterVolumeIndex) end








---
-- @param number uiScale
-- @return integer uiScaleIndex
function Utils.getUIScaleIndex(uiScale) end













---
-- @param integer uiScaleIndex
-- @return number scale
function Utils.getUIScaleFromIndex(uiScaleIndex) end








---
-- @param number volume
-- @return integer index
function Utils.getRecordingVolumeIndex(volume) end

















---
-- @param integer index
-- @return number volume
function Utils.getRecordingVolumeFromIndex(index) end








---
-- @param string filename
-- @param string? baseDir
-- @return string? filename
-- @return boolean? useModDirectory
function Utils.getFilename(filename, baseDir) end




























---Returns file name in given path
-- example: Utils.getFilenameFromPath("dirA/dirB/fileA.xml") -> fileA.xml
-- @param string path path
-- @return string filename filename
function Utils.getFilenameFromPath(path) end






---Returns directory path of given file path
-- example: Utils.getDirectory("dirA/dirB/dirC/fileA.xml") -> dirA/dirB/dirC
-- @param string filePath
-- @return string? directoryPath
function Utils.getDirectory(filePath) end










---Returns name of the directory of the givn directory path
-- example: Utils.getDirectoryName("dirA/dirB/dirC/") -> dirC
-- @param string directoryPath directory path
-- @return string? directoryName
function Utils.getDirectoryName(directoryPath) end













---Collapses all '../' from a path, returns nil if not enough parents elements are present
-- @param string path e.g. data/vehicles/abc/../../shared/xml/schema/def.xsd
-- @return string? resolvedPath path where all '../' upper directory were collapsed or nil if not possible
function Utils.resolveRelativePath(path) end


















---Check if a filepath contains invalid characters such as backslashes
-- @param string path
-- @return boolean hasInvalidCharacters
-- @return string? invalidCharacterDesc invalid character description to use in logging
function Utils.getPathIsValid(path) end









---
-- @param number forceLimit1
-- @param number forceLimit2
-- @return number forceLimit fallback -1
function Utils.getMaxJointForceLimit(forceLimit1, forceLimit2) end







---
-- @param function oldFunc
-- @param function newFunc
-- @return function newFunc
function Utils.appendedFunction(oldFunc, newFunc) end











---
-- @param function oldFunc
-- @param function newFunc
-- @return function newFunc
function Utils.prependedFunction(oldFunc, newFunc) end











---
-- @param function oldFunc
-- @param function newFunc
-- @return function newFunc
function Utils.overwrittenFunction(oldFunc, newFunc) end













---Shuffle items of a list in situ
-- @param table t list to shuffle
function Utils.shuffle(t) end












---
-- @param string filename
-- @param boolean excludePath
-- @return string cleanFilename
-- @return string extension
function Utils.getFilenameInfo(filename, excludePath) end



















---Returns true if given input is not nil and matches 'true' (case-insensitive), false otherwise
-- @param string? booleanString
-- @return boolean boolValue true if string equals 'true' (case-insensitive), false otherwise
function Utils.stringToBoolean(booleanString) end





---Converts console parameters from "nil" to nil or returns the string otherwise
-- nil -> nil
-- "nil" -> nil
-- "abc" -> "abc"
-- @param string str
-- @return string? value
function Utils.parseConsoleParameter(str) end












---Takes string and returns time in minutes since midnight or nil
-- @param string value expected fromat: hh:mm
-- @return float? minutes, nil if format is wrong or time is out of valid range
function Utils.getMinuteOfDayFromTime(value) end

















---Format the time using minutes since midnight
-- @param float timeInMinutes
-- @return string timeStr time string in hh:mm format
function Utils.formatTime(timeInMinutes) end








---
-- @param float x screenspace x [0 1]
-- @param float y screenspace y [0 1]
-- @param float textSize
-- @param table texts
-- @param float spacingX screenspace x spacing
-- @param table? aligns alignment for each text entry/index {[textIndex] = RenderText.ALIGN_*}, default ALIGN_LEFT
function Utils.renderMultiColumnText(x, y, textSize, texts, spacingX, aligns) end

















---
-- @return boolean CoinOrToss
function Utils.getCoinToss() end




---
-- @param number mean
-- @param number sigmaSq
-- @return number z01
-- @return number z02
function Utils.getNormallyDistributedRandomVariables(mean, sigmaSq) end


















---
-- @param entityId node
-- @param number speed
-- @return number cx
-- @return number cy
-- @return number cz
function Utils.getIntersectionOfLinearMovementAndTerrain(node, speed) end































---Clear a specified bit from a bitmask
-- @param integer bitMask 32 bit mask
-- @param integer bit bit index [0..31]
-- @return integer bitMask
function Utils.clearBit(bitMask, bit) end





---Set a specified bit in a bitmask
-- @param integer bitMask 32 bit mask
-- @param integer bit bit index [0..31]
-- @return integer bitMask
function Utils.setBit(bitMask, bit) end





---Get if a bit is set in a bitmask
-- @param integer bitMask 32 bit mask
-- @param integer bit bit index [0..31]
-- @return boolean isSet
function Utils.isBitSet(bitMask, bit) end





---Clears all given flags from bitmask
-- Not to be confused with bit indices
-- @param integer bitMask 32 bit mask
-- @param integer ... flags to clear
-- @return integer bitMask mask with given flags removed
function Utils.clearFlags(bitMask, ...) end






---renderTextAtWorldPosition
-- @param float x world position x
-- @param float y world position y
-- @param float z world position z
-- @param string text
-- @param float? textSize normalized screenspace text size
-- @param float? textOffset normalized screenspace text offset
-- @param float? r
-- @param float? g
-- @param float? b
-- @param float? a
function Utils.renderTextAtWorldPosition(x, y, z, text, textSize, textOffset, r, g, b, a) end





































---Get r g b a values from a green->red gradient based on given factor, where factor 0 => green, 1 => red
-- @param float factor
-- @return float r
-- @return float g
-- @return float b = 0
-- @return float a = 1
function Utils.getGreenRedBlendedColor(factor) end







---
-- @param string textMask
-- @return string textFormatStr
-- @return string textFormatPrecision
function Utils.maskToFormat(textMask) end




































---Find the best matching string from a list of strings using levenshtein distance, case insensitive by default.
-- If there are multiple entries with the same distance the first one is returned,
-- @param string str
-- @param array listOfStrings
-- @param integer? maxDistance maximum allowed levenshtein distance, default: unlimited
-- @param boolean? caseSensitive compare case sensitive, default: false
-- @return string? bestMatch element from given listOfString which has the smallest levenshtein distance to given str
-- @return integer bestMatchLevenshteinDistance levenshtein distance of the match
function Utils.getClosestMatchingString(str, listOfStrings, maxDistance, caseSensitive) end
























---
-- @param string str
-- @return integer count
function Utils.getNumOfWords(str) end





---Compare two version numbers provided as arrays in format {a,b,c,...}
-- 1: version1 > version2
-- -1: version1 < version2
-- 0: version1 == version2
-- For comparision of strings see Utils.compareVersionStrings
-- @param array version1 {a, b, c, d, ...}
-- @param array version2 {a, b, c, d, ...}
-- @return integer comparisonValue 1: version1 > version2; -1: version1 < version2; 0: version1 == version2
function Utils.compareVersions(version1, version2) end


















---Compare two version numbers provided as string in format "a.b.c.d"
-- 1: version1 > version2
-- -1: version1 < version2
-- 0: version1 == version2
-- @param string version1 a.b.c.d
-- @param string version2 a.b.c.d
-- @return integer comparisonValue 1: version1 > version2; -1: version1 < version2; 0: version1 == version2
function Utils.compareVersionStrings(version1, version2) end
