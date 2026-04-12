-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---This class handles all logging
Logging = {}


















---Prints a xml warning to console and logfile, prepends 'Warning (<xmlFilename>):'
-- @param table|integer|string xmlFile xml file object or xml handle
-- @param string warningMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.xmlWarning(xmlFile, warningMessage, ...) end






---Prints a xml error to console and logfile, prepends 'Error (<xmlFilename>):'
-- @param table|integer|string xmlFile xml file object or xml handle
-- @param string errorMessage the error message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in error message
function Logging.xmlError(xmlFile, errorMessage, ...) end






---Prints a xml info to console and logfile, prepends 'Info (<xmlFilename>):'
-- @param table|integer|string xmlFile xml file object or xml handle
-- @param string infoMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.xmlInfo(xmlFile, infoMessage, ...) end






---Prints an i3d node warning to console and logfile, prepends 'Warning (<nodeNamePath> (<nodeIndexPath>)):'
-- @param entityId node i3d node entityId to include in the output
-- @param string warningMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.i3dWarning(node, warningMessage, ...) end






---Prints an i3d node error to console and logfile, prepends 'Error (<nodeNamePath> (<nodeIndexPath>)):'
-- @param entityId node i3d node entityId to include in the output
-- @param string errorMessage the error message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in error message
function Logging.i3dError(node, errorMessage, ...) end






---Prints an i3d node info to console and logfile, prepends 'Info (<nodeNamePath> (<nodeIndexPath>)):'
-- @param entityId node i3d node entityId to include in the output
-- @param string infoMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.i3dInfo(node, infoMessage, ...) end









































---Prints a warning to console and logfile, prepends 'Warning:'
-- @param string warningMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.warning(warningMessage, ...) end





---Prints an error to console and logfile, prepends 'Error:'
-- @param string errorMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.error(errorMessage, ...) end





---Prints an info to console and logfile, prepends 'Info:'
-- @param string infoMessage the warning message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in warning message
function Logging.info(infoMessage, ...) end






---Prints an fatal error to console and logfile and stops the game. To be used for unrecoverable errors only
-- @param string fatalMessage the error message. Can contain string-format placeholders
-- @param any ... variable number of parameters. Depends on placeholders in fatal message
function Logging.fatal(fatalMessage, ...) end
