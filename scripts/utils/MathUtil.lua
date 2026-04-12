-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Util for mathematic operations
-- @category Utils
MathUtil = {}

---Returns if the given value is nan
-- @param float value a value
-- @return boolean true if value is nan else false
function MathUtil.isNan(value) end




---Return if the given number is an integer
-- @param float number
-- @return boolean isInteger
function MathUtil.isInt(number) end




---Return if the given number is Infinity
-- @param number number
-- @return boolean isInf
function MathUtil.isInf(number) end




---Return if the given number is Finite
-- @param number number
-- @return boolean isFinite
function MathUtil.isFinite(number) end




---Check if all provided parameters are a valid translation or rotation value: not nil, not nan, not (-)inf
-- @param any ... values to check
-- @return boolean isValid true of all parameters were valid, false otherwise
function MathUtil.getIsValidTransformationValue(...) end
























---Returns random float between lowerValue and upperValue (both inclusive)
-- @param float lowerValue
-- @param float upperValue
-- @return float randomFloat
function MathUtil.randomFloat(lowerValue, upperValue) end




---Rounds number value to the given decimal precision
-- @param float value a value
-- @param float? precision number of decimals to round to, default: 0 (= round to integer)
-- @return float rounded value
function MathUtil.round(value, precision) end













---Returns the radian value of a given angle in degrees
-- @param float degValue angle in degrees
-- @return float value radian angle
function MathUtil.degToRad(degValue) end








---Returns interpolated value between two given values
-- @param float v1 start value
-- @param float v2 end value
-- @param float alpha alpha
-- @return float value interpolated value
function MathUtil.lerp(v1, v2, alpha) end




---Returns alpha based on current value
-- @param float v1 start value
-- @param float v2 end value
-- @param float cv current value
-- @return float alpha alpha
function MathUtil.inverseLerp(v1, v2, cv) end


























---Returns true if the value is out of the given range
-- @param float value value
-- @param float limit1 limit 1
-- @param float limit2 limit 2
-- @return float isOutOfBounds is out of bounds
function MathUtil.getIsOutOfBounds(value, limit1, limit2) end








---Returns the floored percent
-- @param float value a value
-- @param float maxValue max value
-- @return float value the floored percent value
function MathUtil.getFlooredPercent(value, maxValue) end















---Returns the floored clamped value
-- @param float value a value
-- @param float minValue min value
-- @param float maxValue max value
-- @return float value the floored clamped value
function MathUtil.getFlooredBounded(value, minValue, maxValue) end










---Returns a valid limit in the range of -pi to pi
-- @param float limit a radian angle
-- @return float angle the resized angle in the range -pi to pi
function MathUtil.getValidLimit(limit) end












---Returns the difference between two rad angles
-- @param float alpha a radian angle
-- @param float beta a radian angle
-- @return float angle the radian difference in range -pi to pi
function MathUtil.getAngleDifference(alpha, beta) end






---Converts the given euler yaw and pitch into a direction vector.
-- @param float yaw The yaw (y rotation) of the euler.
-- @param float pitch The pitch (x rotation) of the euler.
-- @return float x The x axis of the direction.
-- @return float y The y axis of the direction.
-- @return float z The z axis of the direction.
function MathUtil.eulerToDirection(yaw, pitch)

    -- The length of the x and y axis. When the direction is pointing straight up or down; this will be 0.
    local xzLength = math.cos(-pitch)

    -- Rotate the node around the y axis.
    return xzLength * math.sin(yaw), math.sin(-pitch), xzLength * math.cos(yaw)
end


---Calculates the pitch and yaw in radians of the given direction.
-- @param float directionX The x axis of the direction.
-- @param float directionY The y axis of the direction.
-- @param float directionZ The z axis of the direction.
-- @return float pitch The pitch (x axis) of the rotation.
-- @return float yaw The yaw (y axis) of the rotation.
function MathUtil.directionToPitchYaw(directionX, directionY, directionZ)
    return math.asin(-directionY), math.atan2(directionX, directionZ)
end

---Returns length of 2d vector
-- @param float x x
-- @param float y y
-- @return float length length
function MathUtil.vector2Length(x, y) end




---Returns squared length of 2d vector
-- @param float x x
-- @param float y y
-- @return float length square length
function MathUtil.vector2LengthSq(x, y) end




---Returns normalized vector
-- @param float x x
-- @param float y y
-- @return float x normalized x
-- @return float y normalized y
function MathUtil.vector2Normalize(x, y) end






---Returns a scaled vector
-- @param float x x
-- @param float y y
-- @param float length
-- @return float x normalized x
-- @return float y normalized y
function MathUtil.vector2SetLength(x, y, length) end









---Returns a linear interpolated 2 vector based on given alpha
-- @param float x1 x1
-- @param float y1 y1
-- @param float x2 x2
-- @param float y2 y2
-- @param float alpha alpha value
-- @return float x interpolated x
-- @return float y interpolated y
function MathUtil.vector2Lerp(x1, y1, x2, y2, alpha) end






---Returns length of 3d vector
-- @param float x x
-- @param float y y
-- @param float z z
-- @return float length length
function MathUtil.vector3Length(x, y, z) end




---Returns squared length of 3d vector
-- @param float x x
-- @param float y y
-- @param float z z
-- @return float length square length
function MathUtil.vector3LengthSq(x, y, z) end




---Returns normalized vector
-- @param float x x
-- @param float y y
-- @param float z z
-- @return float x normalized x
-- @return float y normalized y
-- @return float z normalized z
function MathUtil.vector3Normalize(x, y, z) end






---Returns a scaled vector
-- @param float x x
-- @param float y y
-- @param float z z
-- @param float length scale length
-- @return float x scaled x
-- @return float y scaled y
-- @return float z scaled z
function MathUtil.vector3SetLength(x, y, z, length) end










---Returns a clamped vector based on min and max vector length
-- @param float x x
-- @param float y y
-- @param float z z
-- @param float minVal min length
-- @param float maxVal max length
-- @return float x clamped x
-- @return float y clamped y
-- @return float z clamped z
function MathUtil.vector3Clamp(x, y, z, minVal, maxVal) end










---Returns a linear interpolated vector based on given alpha
-- @param float x1 x1
-- @param float y1 y1
-- @param float z1 z1
-- @param float x2 x2
-- @param float y2 y2
-- @param float z2 z2
-- @param float alpha alpha value
-- @return float x interpolated x
-- @return float y interpolated y
-- @return float z interpolated z
function MathUtil.vector3Lerp(x1, y1, z1, x2, y2, z2, alpha) end


























---Returns a linear interpolated vector based on given alpha
-- @param table v1 vector1
-- @param table v2 vector2
-- @param float alpha alpha value
-- @return float x interpolated x
-- @return float y interpolated y
-- @return float z interpolated z
function MathUtil.vector3ArrayLerp(v1, v2, alpha) end








---Returns a linear interpolated inverse vector based on given alpha
-- @param array v1 vector1
-- @param array v2 vector2
-- @param array cv alpha array
-- @return number value
function MathUtil.inverseVector3ArrayLerp(v1, v2, cv) end

















---Transform a vector by matrix multiplication, the matrix is given row by row
-- @param float x x
-- @param float y y
-- @param float z z
-- @param float m11 m11
-- @param float m12 m12
-- @param float m13 m13
-- @param float m21 m21
-- @param float m22 m22
-- @param float m23 m23
-- @param float m31 m31
-- @param float m32 m32
-- @param float m33 m33
-- @return float x transformed x
-- @return float y transformed y
-- @return float z transformed z
function MathUtil.vector3Transformation(x, y, z, m11, m12, m13, m21, m22, m23, m31, m32, m33) end














---Returns the dot product of 2 vectors
-- @param float ax ax
-- @param float ay ay
-- @param float az az
-- @param float bx bx
-- @param float by by
-- @param float bz bz
-- @return float the dot product
function MathUtil.dotProduct(ax, ay, az, bx, by, bz) end




---Returns the cross product of 2 vectors
-- @param float ax ax
-- @param float ay ay
-- @param float az az
-- @param float bx bx
-- @param float by by
-- @param float bz bz
-- @return float x x
-- @return float y y
-- @return float z z
function MathUtil.crossProduct(ax, ay, az, bx, by, bz) end




---Returns the angle between two vectors
-- @param float dirX1 X Direction 1
-- @param float dirY1 Y Direction 1
-- @param float dirZ1 Z Direction 1
-- @param float dirX2 X Direction 2
-- @param float dirY2 Y Direction 2
-- @param float dirZ2 Z Direction 2
-- @return float angle angle
function MathUtil.getVectorAngleDifference(dirX1, dirY1, dirZ1, dirX2, dirY2, dirZ2) end







---Returns the angle between two vectors
-- @param float dirX1 X Direction 1
-- @param float dirZ1 Z Direction 1
-- @param float dirX2 X Direction 2
-- @param float dirZ2 Z Direction 2
-- @return float angle angle
function MathUtil.getSignedAngleBetweenVectors2D(dirX1, dirZ1, dirX2, dirZ2) end






---Returns the angle to rotate from the z axis around the y axis (if x==0, the angle is 0 or 180°). This is unlike the default specification, where the rotation is 0 at the x axis
-- @param float dx dx
-- @param float dz dz
-- @return float y rotation
function MathUtil.getYRotationFromDirection(dx, dz) end




---Returns the x and z direction based on the given y rotation
-- @param float rotY y rotation
-- @return float x x direction
-- @return float z z direction
function MathUtil.getDirectionFromYRotation(rotY) end




---Returns an 2d vector limited by min and max rotation
-- @param float x x direction
-- @param float y y direction
-- @param float minRot min rot
-- @param float maxRot max rot
-- @return float x limited x direction
-- @return float z limited z direction
function MathUtil.getRotationLimitedVector2(x, y, minRot, maxRot) end















---Multiply quaternion with given vectors
-- @param float quatX quaternion x
-- @param float quatY quaternion y
-- @param float quatZ quaternion z
-- @param float quatW quaternion w
-- @param float vecX vector x
-- @param float vecY vector y
-- @param float vecZ vector z
-- @return float dirX x direction
-- @return float dirY Y direction
-- @return float dirZ Z direction
function MathUtil.quaternionVectorMultiplication(quatX, quatY, quatZ, quatW, vecX, vecY, vecZ) end




















---Returns the projected point on a given line
-- @param float px x position
-- @param float pz z position
-- @param float lineX x position
-- @param float lineZ z position
-- @param float normlineDirX normalized x direction
-- @param float normlineDirZ normalized z direction
-- @return float x x position
-- @return float z z position
function MathUtil.projectOnLine(px, pz, lineX, lineZ, normlineDirX, normlineDirZ) end







---Returns the dot product on a given line
-- @param float px x position
-- @param float pz z position
-- @param float lineX x position
-- @param float lineZ x position
-- @param float normlineDirX normalized x direction
-- @param float normlineDirZ normalized z direction
-- @return float dot product
function MathUtil.getProjectOnLineParameter(px, pz, lineX, lineZ, normlineDirX, normlineDirZ) end







---Returns the multiplication of two quaternions
-- @param float x x1
-- @param float y y1
-- @param float z z1
-- @param float w w1
-- @param float x1 x2
-- @param float y1 y2
-- @param float z1 z2
-- @param float w1 w2
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.quaternionMult(x, y, z, w, x1, y1, z1, w1) end







---Returns the normalized quaternion
-- @param float x x
-- @param float y y
-- @param float z z
-- @param float w w
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.quaternionNormalized(x, y, z, w) end








---Returns the linear interpolated quaternion
-- @param float x1 x1
-- @param float y1 y1
-- @param float z1 z1
-- @param float w1 w1
-- @param float x2 x2
-- @param float y2 y2
-- @param float z2 z2
-- @param float w2 w2
-- @param float t interpolation value
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.slerpQuaternion(x1, y1, z1, w1, x2, y2, z2, w2, t) end

















---Returns normalized rotation for the shortest path from current rotation to target rotation
-- @param float targetRotation the target rotation
-- @param float curRotation the current rotation
-- @return float rotation the final rotation
function MathUtil.normalizeRotationForShortestPath(targetRotation, curRotation) end















---Returns the normalized shortest path from current quaternion to target quaternion
-- @param float x1 x1
-- @param float y1 y1
-- @param float z1 z1
-- @param float w1 w1
-- @param float x2 x2
-- @param float y2 y2
-- @param float z2 z2
-- @param float w2 w2
-- @param float t alpha
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.nlerpQuaternionShortestPath(x1, y1, z1, w1, x2, y2, z2, w2, t) end













---Returns the shortest path from current quaternion to target quaternion
-- @param float x1 x1
-- @param float y1 y1
-- @param float z1 z1
-- @param float w1 w1
-- @param float x2 x2
-- @param float y2 y2
-- @param float z2 z2
-- @param float w2 w2
-- @param float t alpha
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.slerpQuaternionShortestPath(x1, y1, z1, w1, x2, y2, z2, w2, t) end


























---Returns the shortest path from current quaternion to target quaternion (mad = multiply and add)
-- @param float x x1
-- @param float y y1
-- @param float z z1
-- @param float w w1
-- @param float x1 x2
-- @param float y1 y2
-- @param float z1 z2
-- @param float w1 w2
-- @param float t alpha
-- @return float x x part of quaternion
-- @return float y y part of quaternion
-- @return float z z part of quaternion
-- @return float w w part of quaternion
function MathUtil.quaternionMadShortestPath(x, y, z, w, x1, y1, z1, w1, t) end









---Returns the distance to a rectangle
-- @param float posX x position
-- @param float posZ z position
-- @param float sx x position of rectangle
-- @param float sz z position of rectangle
-- @param float dx x direction of rectangle
-- @param float dz z direction of rectangle
-- @param float length length of rectangle
-- @param float widthHalf half width of rectangle
-- @return float distance distance to rectangle
function MathUtil.getDistanceToRectangle2D(posX, posZ, sx, sz, dx, dz, length, widthHalf) end
































---Returns the distance to a line segment
-- @param float x x position
-- @param float z z position
-- @param float sx x position of rectangle
-- @param float sz z position of rectangle
-- @param float dx x direction of rectangle
-- @param float dz z direction of rectangle
-- @param float length length of rectangle
-- @return float distance distance to line segment
function MathUtil.getSignedDistanceToLineSegment2D(x, z, sx, sz, dx, dz, length) end






















---Returns the line-line (infinite length) intersection point
-- Use MathUtil.getLineSegmentsIntersection to get intersection of line segments
-- @param float x1 x1 position
-- @param float z1 z1 position
-- @param float dirX1 line1 x direction
-- @param float dirZ1 line1 z direction
-- @param float x2 x2 position
-- @param float z2 z2 position
-- @param float dirX2 line2 x direction
-- @param float dirZ2 line2 z direction
-- @return boolean hasIntersection true if both lines intersect
-- @return float t1 x position
-- @return float t2 z position
function MathUtil.getLineLineIntersection2D(x1, z1, dirX1, dirZ1, x2, z2, dirX2, dirZ2) end











---Get intersection of two line segments defined by their start and end positions
-- Returns false for collinear segments
-- @param float ax1 line segment A start x
-- @param float az1 line segment A start z
-- @param float ax2 line segment A end x
-- @param float az2 line segment A end z
-- @param float bx1 line segment B start x
-- @param float bz1 line segment B start z
-- @param float bx2 line segment B end x
-- @param float bz2 line segment B end z
-- @return boolean hasIntersection
-- @return float x intersection point x
-- @return float z intersection point z
function MathUtil.getLineSegmentsIntersection(ax1, az1, ax2, az2, bx1, bz1, bx2, bz2) end




















---Get intersection parameter of two line segments defined by their start and end positions
-- Returns false for collinear segments
-- @param float ax1 line segment A start x
-- @param float az1 line segment A start z
-- @param float ax2 line segment A end x
-- @param float az2 line segment A end z
-- @param float bx1 line segment B start x
-- @param float bz1 line segment B start z
-- @param float bx2 line segment B end x
-- @param float bz2 line segment B end z
-- @return boolean hasIntersection
-- @return float a intersection position on line a
-- @return float b intersection position on line b
function MathUtil.getLineSegmentsIntersectionParameter(ax1, az1, ax2, az2, bx1, bz1, bx2, bz2) end

















---Get if two line segments defined by their start and end positions are intersecting (including collinear)
-- @param float ax1 line segment A start x
-- @param float az1 line segment A start z
-- @param float ax2 line segment A end x
-- @param float az2 line segment A end z
-- @param float bx1 line segment B start x
-- @param float bz1 line segment B start z
-- @param float bx2 line segment B end x
-- @param float bz2 line segment B end z
-- @param boolean? allowEndStartSamePos default: false; if true the function will return false if one segment is the continuation of the other, e.g. in a contour of a polygon
-- @return boolean hasIntersection
-- @return boolean areColinear
function MathUtil.getAreLineSegmentsIntersecting(ax1, az1, ax2, az2, bx1, bz1, bx2, bz2, allowEndStartSamePos) end
























































---Returns if the bounding box of two 2d lines intersect
-- @param float ax1 start pos x of line a
-- @param float ay1 start pos y of line a
-- @param float ax2 end pos x of line a
-- @param float ay2 end pos y of line a
-- @param float bx1 start pos x of line b
-- @param float by1 start pos y of line b
-- @param float bx2 end pos x of line b
-- @param float by2 end pos y of line b
-- @return boolean intersect true if both bounding boxes intersect
function MathUtil.getLineBoundingVolumeIntersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2) end







---Returns if rectangle and line have intersection
-- @param float x1 x1 position
-- @param float z1 z1 position
-- @param float dirX1 rectangle x1 direction
-- @param float dirZ1 rectangle z1 direction
-- @param float dirX2 rectangle x2 direction
-- @param float dirZ2 rectangle z2 direction
-- @param float x3 line x position
-- @param float z3 line z position
-- @param float dirX3 line x direction
-- @param float dirZ3 line z direction
-- @return boolean hasIntersection true if the line segment is completly in the rectangle OR if it intersects with one of the four rectangle sides
function MathUtil.hasRectangleLineIntersection2D(x1, z1, dirX1, dirZ1, dirX2, dirZ2, x3, z3, dirX3, dirZ3) end


































































---Returns circle-circle intersection points
-- @param float x1 x1 position
-- @param float y1 y1 position
-- @param float r1 radius 1
-- @param float x2 x2 position
-- @param float y2 y2 position
-- @param float r2 radius 2
-- @return float pos1X x pos of intersection 1, else nil
-- @return float pos1Y y pos of intersection 1, else nil
-- @return float pos2X x pos of intersection 2, else nil
-- @return float pos2Z z pos of intersection 2, else nil
function MathUtil.getCircleCircleIntersection(x1, y1, r1, x2, y2, r2) end












































---Returns if 2 spheres have an intersection
-- @param float x1 x1 position
-- @param float y1 y1 position
-- @param float z1 z1 position
-- @param float r1 radius 1
-- @param float x2 x2 position
-- @param float y2 y2 position
-- @param float z2 z2 position
-- @param float r2 radius 2
-- @return boolean hasIntersection true if spheres have an intersection else false
function MathUtil.hasSphereSphereIntersection(x1, y1, z1, r1, x2, y2, z2, r2) end























































































---
-- @param float startX line segment start x
-- @param float startZ line segment start z
-- @param float endX line segment end x
-- @param float endZ line segment end z
-- @param float pointX point x
-- @param float pointZ point z
-- @return float distance minimum distance from point to line segment
function MathUtil.getDistanceToLineSegment2D(startX, startZ, endX, endZ, pointX, pointZ) end



















































---Get distance between two 2D points
-- @param float x1 point1 x
-- @param float y1 point1 y
-- @param float x2 point2 x
-- @param float y2 point2 y
-- @return float distance
function MathUtil.getPointPointDistance(x1, y1, x2, y2) end






---Get squared distance between two 2D points
-- useful for more performant distance comparisons without sqrt
-- @param float x1 point1 x
-- @param float y1 point1 y
-- @param float x2 point2 x
-- @param float y2 point2 y
-- @return float squaredDistance
function MathUtil.getPointPointDistanceSquared(x1, y1, x2, y2) end






---Converts a area to hectars
-- @param float area area
-- @param float pixelToSqm pixel density
-- @return float area area in hectars
function MathUtil.areaToHa(area, pixelToSqm) end




---
-- @param number area
-- @return number sqm
function MathUtil.haToSqm(area) end




---Converts an inch distance to meters
-- @param float inchValue the inch value to convert
-- @return float mValue
function MathUtil.inchToM(inchValue) end




---Converts an meter distance to inch
-- @param float mValue the meter value to convert
-- @return float inchValue
function MathUtil.mToInch(mValue) end




---
-- @param integer ms
-- @return number minutes
function MathUtil.msToMinutes(ms) end




---
-- @param integer ms
-- @return number hours
function MathUtil.msToHours(ms) end




---
-- @param integer ms
-- @return number days
function MathUtil.msToDays(ms) end




---
-- @param number minutes
-- @return integer ms
function MathUtil.minutesToMs(minutes) end




---
-- @param number hours
-- @return integer ms
function MathUtil.hoursToMs(hours) end




---
-- @param integer days
-- @return integer ms
function MathUtil.daysToMs(days) end




---
-- @param number mps
-- @return number kmh
function MathUtil.mpsToKmh(mps) end




---
-- @param number kmh
-- @return number mps
function MathUtil.kmhToMps(kmh) end




---
-- @param integer rpm
-- @param number radius
-- @return number mps
function MathUtil.rpmToMps(rpm, radius) end




---
-- @param number startWorldX
-- @param number startWorldZ
-- @param number widthWorldX
-- @param number widthWorldZ
-- @param number heightWorldX
-- @param number heightWorldZ
-- @return number startWorldX
-- @return number startWorldZ
-- @return number startWorldX
-- @return number startWorldZ
-- @return number width
-- @return number height
function MathUtil.getXZWidthAndHeight(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ) end




---
-- @param number startWorldX
-- @param number startWorldZ
-- @param number widthWorldX
-- @param number widthWorldZ
-- @param number heightWorldX
-- @param number heightWorldZ
-- @param number offset
-- @return number newStartWorldX
-- @return number newStartWorldZ
-- @return number newWidthWorldX
-- @return number newWidthWorldZ
-- @return number newHeightWorldX
-- @return number newHeightWorldZ
function MathUtil.getWorldParallelogramOffset(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, offset) end




























---Returns number of set bits for given number/bitmask. Example: getNumOfSetBits(7) => 3 (bits 0, 1, 2), getNumOfSetBits(8) => 1 (bit 3)
-- @param integer bitmask
-- @return integer numOfSetBits
function MathUtil.getNumOfSetBits(bitmask) end








---Get the bitmask from given bits. Example: bitsToMask(0,2) => 5
-- @param integer ... bits which are set, starting at 0
-- @return integer mask mask from all provided bits
function MathUtil.bitsToMask(...) end









---Get list of bits from decimal number. Example: getBinary(5) => {1=1, 2=0, 3=1}
-- @param integer number
-- @return array bits
function MathUtil.getBinary(number) end












---Get list of set bits from number. Example: numbetToSetBits(5) => {0, 2}
-- @param integer number
-- @return array setBits
function MathUtil.numberToSetBits(number) end













---Get string of comma set bits from number. Bits start at 0. Example: numberToSetBitsStr(5) => 0, 2
-- @param integer number
-- @param string? separator separator to use between the bits, default: ", "
-- @return string returnStr
function MathUtil.numberToSetBitsStr(number, separator) end
















---Get number of bits required to represent given positive integer.
-- Returned value is at least 1.
-- @param integer integer (>= 1)
-- @return integer numRequiredBits of bits required to represent given number. returned value is at least 1 even of number is 0
function MathUtil.getNumRequiredBits(integer) end












---Returns the brightness of a color [0..1]. See https://en.wikipedia.org/wiki/Relative_luminance
-- @param float r red value
-- @param float g green value
-- @param float b blue value
-- @return float brightness brightness
function MathUtil.getBrightnessFromColor(r, g, b) end




---
-- @param number x
-- @param number y
-- @param number z
-- @return number angle radian
function MathUtil.getHorizontalRotationFromDeviceGravity(x, y, z) end





























---
-- @param number x
-- @param number y
-- @param number z
-- @return number angle normalize angle
function MathUtil.getSteeringAngleFromDeviceGravity(x, y, z) end






















---
-- @param number p0 previousPoint
-- @param number p1 startPoint
-- @param number p2 endPoint
-- @param number p3 nextPoint
-- @param number t interpolationFactor
-- @return number catmullRomInterpolatedValue
function MathUtil.catmullRom(p0, p1, p2, p3, t) end









---Get if two number values are equal within a threshold/epison.
-- If any of the values is nil function will return false
-- @param float? a
-- @param float? b
-- @param float? epsilon default: 0.0001
-- @return boolean areEqualWithinEpsilon
function MathUtil.equalEpsilon(a, b, epsilon) end









---Returns an iterator for the specified range (start and end inclusive)
-- Compared to the native numeric 'for' loop this iterator not stop short of the last entry if floats are used
-- Raises error if endless range is defined
-- @param float startVal
-- @param float endVal
-- @param float step
-- @return function floatIterator returning steppedValue
function MathUtil.floatRange(startVal, endVal, step) end










































---
-- @param number min
-- @param number max
-- @param number x
-- @return number interpolatedValue
function MathUtil.smoothstep(min, max, x) end





---
-- @param number value
-- @param integer step
-- @return number value
function MathUtil.snapValue(value, step) end










---Returns the 1-based index/position of the first digit behind the decial point which is not 0 for any input in ]-1, 1[ range, otherwise 0 (abs input is >= 1). e.g. 0.002 -> 3; 1.01 -> 0
-- @param float number
-- @return integer fractionDigitIndex
function MathUtil.getIndexOfFirstNonZeroFractionDigit(number) end














---
-- @param number x
-- @param number y
-- @param number angle radian
-- @return number rotatedX
-- @return number rotatedY
function MathUtil.vector2Rotate(x, y, angle) end









---
-- @param array vertices
-- @return number size absolut
function MathUtil.getPolygon2DSize(vertices) end




























---
-- @param array vertices
-- @param number precision
-- @return number minX
-- @return number minY
function MathUtil.getPolygonLabel(vertices, precision) end









































































































































































---Returns a symmetric parabolic curve with fixed edge values and a controllable dip at the midpoint
-- @param number value Input in range [0..1]
-- @param number alpha Dip strength, 0 = flat line, 1 = maximum dip
-- @param number maxValue Value at the edges (x=0 and x=1)
-- @return number curveValue
function MathUtil.symmetricDipCurve(value, alpha, maxValue) end
