//
//  XMLConverter.swift
//  PlexConnectApp
//
//  Created by Baa on 29.09.15.
//  Copyright © 2015 Baa. All rights reserved.
//

import Foundation



class cXmlConverter {
    var pmsId: String? = ""
    var pmsPath: String? = ""
    //var query: [String: String] = [:]
    
    // jump tables - forward declaration (sort of)
    var processStructure: [String: (_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String) ]
    var processAttrib: [String: (_self: cXmlConverter, XML: XMLIndexer?, par: String) -> String ]

    // local variables
    var template: String = ""
    var xmlCache: [String: XMLIndexer] = [:]
    var variables: [String: String] = [:]

    init() {
        // jump-table to commands modifying the XML structure: COPY, CUT
        processStructure = [
            "COPY": processCOPY!,
            "IF": processIF!,
            "CUT": processCUT!,
            "IFNODE": processIFNODE!,
            "PMSLOOP": processPMSLOOP!,
            "XML": processXML!,
        ]
        
        // jump table to commands processing attributes: VAL, VIDEOURL, ...
        processAttrib = [
            "VAL": processVAL!,
            "EVAL": processEVAL!,
            "DURATION": processDURATION!,
            "SEASONEPISODE": processSEASONEPISODE!,
            "CHK": processCHK!,
            "PMSID": processPMSID!,
            "PMSVAL": processPMSVAL!,
            "USRVAL": processUSRVAL!,
            "SET": processSET!,
            "GET": processGET!,
            "URL": processURL!,
            "VIDEOURL": processVIDEOURL!,
            "IMAGEURL": processIMAGEURL!,
            "TEXT": processTEXT!,
            "SETTING": processSETTING!,
        ]
    }
    
    
    
    func setup(reqFile: String,
        pmsId: String?, pmsPath: String?, query: [String: String]) {
            self.template = readResource(reqFile) as String
            self.pmsId = pmsId
            self.pmsPath = pmsPath
            //self.query = query
            
            self.variables = [:]
    }

    
    
    // helper functions
    func getParam(XML: XMLIndexer?, inout par: [String]) -> String {
        var param: String = ""
        if !(par==[]) {
            param = par.removeFirst()
        }
        return param
    }
    
    func getKey(XML: XMLIndexer?, inout par: [String]) -> String {
        var attrib: String = ""
        if !(par==[]) {
            attrib = par.removeFirst()
        }
        var dflt: String = ""
        if !(par==[]) {
            dflt = par.removeFirst()
        }
        
        if attrib.hasPrefix("#") {  // internal variable, no XML needed
            let res = self.variables[attrib]
            if ((res == nil)) {
                return dflt
            }
            return res!
        }
        
        // key/value from XML
        // todo: check for correct XML (see ADDXML()) / getBase()
        if (XML==nil) {
            return dflt
        }
        var elem = XML!
        var lvls = attrib.componentsSeparatedByString("/")
        while (lvls.count>1) {
            // todo: check for special chars - settings, vars, ...  // shouldn't happen, should it?
            elem = elem[lvls.removeFirst()][0]  // always first element? How about indexing?
            if (!elem) {
                return dflt
            }
        }
        
        // get attribute
        // check for special char - settings, vars, ...
        let res = elem.element!.attributes[lvls[0]]
        if ((res == nil)) {
            return dflt
        }
        return res!
    }
    
    
    func getNode(XML: XMLIndexer?, inout par: [String]) -> XMLIndexer? {
        let tag = getParam(XML, par: &par)
        
        // todo: check for correct XML (see ADDXML()) / getBase() (if needed?)
        if (XML==nil) {
            return nil
        }
        var elem = XML!
        var lvls = tag.componentsSeparatedByString("/")
        while (lvls.count>0 && lvls[0] != "" ) {
            // todo: check for special chars - settings, vars, ...  // shouldn't happen, should it?
            elem = elem[lvls.removeFirst()][0]  // always first element? How about indexing?
            if (!elem) {
                return nil
            }
        }
        return elem
    }


    
    // commands modifying the XML structure: COPY, CUT
    var processCOPY: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in
        
        // sanity check
        if (XML==nil) {
            return "[[COPY - XML not found]]"
        }
        
        // recursively process parameters
        let _par_decoded = _self.convert(_par, xmlSection: XML)  // short: let tag=_self.convert(...)
        var par = _par_decoded.componentsSeparatedByString(":")

        // walk the XML tree
        var res = ""
        var elem = XML!
        var tag = _self.getParam(XML, par: &par)
        var lvls = tag.componentsSeparatedByString("/")
        while (lvls.count>1) {
            // todo: check for special chars - settings, vars, ...  // shouldn't happen, should it?
            elem = elem[lvls.removeFirst()][0]  // always first element? How about indexing?
            if (!elem) {
                return "[[COPY - XMLNode not found]]"
            }
        }

        // loop over XML elements and recursively process body
        _self.variables["ix_" + tag] = "0"
        for (ix, _elem) in elem[lvls[0]].enumerate() {
            _self.variables["ix_" + tag] = String(ix)
            res = res + _self.convert(_body, xmlSection: _elem)
        }
        return res
    }

    var processIF: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in

        // recursively process parameters
        let _par_decoded = _self.convert(_par, xmlSection: XML)
        var par = _par_decoded.componentsSeparatedByString(":")
        
        var res = ""
        let key = _self.getParam(XML, par: &par)  // check key exist & get content
        
        // conditionally, recursively process body
        if key.hasPrefix("!") {  // boolean invert
            if !(key != "!" && key != "!0" && key != "!false") {
                res = _self.convert(_body, xmlSection: XML)
            }
        } else {
            if (key != "" && key != "0" && key != "false") {
                res = _self.convert(_body, xmlSection: XML)
            }
        }
        return res
    }

    var processIFNODE: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in
        
        // recursively process parameters
        let _par_decoded = _self.convert(_par, xmlSection: XML)
        var par = _par.componentsSeparatedByString(":")
        
        var res = ""
        let node = _self.getNode(XML, par: &par)  // check if node exists
        if (node != nil) {  // todo: invert?
            res = _self.convert(_body, xmlSection: XML)
        }
        return res
    }
    
    var processCUT: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in
        
        // recursively process body
        var res = _self.convert(_body, xmlSection: XML)  // process body, then check condition downstream

        // recursively process parameters
        let _par_decoded = _self.convert(_par, xmlSection: XML)
        var par = _par_decoded.componentsSeparatedByString(":")
        
        let key = _self.getParam(XML, par: &par)
        // conditionally, recursively process body
        if key.hasPrefix("!") {  // boolean invert
            if !(key != "!" && key != "!0" && key != "!false") {
                res = ""
            }
        } else {
            if (key != "" && key != "0" && key != "false") {
                res = ""
            }
        }
        return res
    }

    var processPMSLOOP: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in

        // recursively process parameters
        let __par = _self.convert(_par, xmlSection: XML)
        var par = __par.componentsSeparatedByString(":")
        
        var tag = _self.getParam(XML,par: &par)
        
        // loop over PMSs
        var res = ""
        _self.variables["ix_" + tag] = "0"
        for (ix, (_pmsId, _pms)) in PlexMediaServerInformation.enumerate() {  // todo: async in parallel?
            if (tag=="owned") {
                if (_pms.getAttribute("owned") != "1") {  // next if this is not owned
                    continue
                }
            } else if (tag=="shared") {
                if (_pms.getAttribute("owned") == "1") {  // next if this is owned
                    continue
                }
            }
            
            // recursively process body
            _self.pmsId = _pmsId
            _self.variables["ix_" + tag] = String(ix)
            res = res + _self.convert(_body, xmlSection: XML)
        }
        
        return res
    }
    
    var processXML: ((_self: cXmlConverter, XML: XMLIndexer?, par: String, body: String) -> (String))? = {
        _self, XML, _par, _body in

        // sanity check
        if (_self.pmsPath == nil) {
            return "[[XML - pmsPath not initialised]]"
        }
        
        // recursively process parameters
        let __par = _self.convert(_par, xmlSection: XML)
        var par = __par.componentsSeparatedByString(":")
        
        var res = ""
        var key = _self.getParam(XML, par: &par)
        key = key.stringByReplacingOccurrencesOfString("&amp;", withString:"&")
        //key = key.stringByReplacingOccurrencesOfString("+", withString: " ")
        //key = key.stringByRemovingPercentEncoding!  // todo: not PercentEncoding, but &amp; and such
        var xmlSection: XMLIndexer? = nil

        if (key.hasPrefix("/")) {
            res = key
        } else if (key=="") {
            res = _self.pmsPath!
        } else {
            res = _self.pmsPath! + "/" + key
        }
        let URL = getPMSAdr(_self.pmsId!, PMSPath: res)

        if _self.xmlCache[URL] != nil {
            // grab cached XML
            xmlSection = _self.xmlCache[URL]!
        } else {
            // request XML and cache it
            let dsptch = dispatch_semaphore_create(0)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                {
                    reqXML(URL,
                        fn_success: {
                            XMLdata in
                            
                            //print(XMLdata)
                            xmlSection = SWXMLHash.parse(XMLdata)
                            dispatch_semaphore_signal(dsptch)
                        },
                        fn_error: {
                            _ in
                            
                            print("***error requesting URL \(URL)")
                            dispatch_semaphore_signal(dsptch)
                        }
                    )
                }
            )
            dispatch_semaphore_wait(dsptch, dispatch_time(DISPATCH_TIME_NOW, httpTimeout))

            _self.xmlCache[URL] = xmlSection
        }
        
        // if xmlSection != nil
        // recursively process body
        res = _self.convert(_body, xmlSection: xmlSection)
        
        return res
    }


    
    // commands processing attributes: VAL, URL, ...
    var processVAL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        let key = _self.getKey(XML, par: &par)
        return key
    }
    
    var processDURATION: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        //let mode = _self.getParam(XML, par: &par)
        var hour: Int = 0, minute: Int = 0, second: Int = 0
        if let duration = Int(_self.getParam(XML, par: &par)) {  // duration in ms
            hour = 0
            minute = duration / 1000/60
            second = 0
        }
        // todo: support mode (sec/min). support better display: hh:mmm / mm:ss
        return "\(minute) minutes"
    }
    
    var processSEASONEPISODE: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        let season = Int(_self.getParam(XML, par: &par))
        let episode = Int(_self.getParam(XML, par: &par))
        let res = String(format: "%0dx%02d", season!, episode!)
        return res
    }
    
    var processURL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        var res = ""

        let template = _self.getParam(XML, par: &par)
        let key = _self.getParam(XML, par: &par)
        let options = _self.getParam(XML, par: &par)
        
        res = TVBaseURL! + "/\(template).xml"
        
        if !(_self.pmsPath==nil) {
            if (key.hasPrefix("/")) {
                res += "?X-PMSPath=\(key)"
            } else if (key=="") {
                res += "?X-PMSPath=\(_self.pmsPath!)"
            } else {
                res += "?X-PMSPath=\(_self.pmsPath!)/\(key)"
            }
        } else {
            if (key.hasPrefix("/")) {
                res += "?X-PMSPath=\(key)"
            } else if (key=="") {
                // do nothing
            } else {
                // todo: key without trailering /... what to do?
            }
        }

        if !(_self.pmsId==nil) {
            res = res + "&amp;X-PMSId="+_self.pmsId!
        }
        res = res + options  // additional options/query string
        
        return res
    }

    var processPMSID: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        if let pmsId = _self.pmsId {
            return pmsId
        }
        return ""
    }
    
    var processPMSVAL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
    
        var par = _par.componentsSeparatedByString(":")
        var key = _self.getParam(XML, par: &par)
        if let pmsId = _self.pmsId {
            return PlexMediaServerInformation[pmsId]!.getAttribute(key)  // todo: check pmsId known
        }
        return ""
    }

    var processUSRVAL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        var key = _self.getParam(XML, par: &par)
        return plexUserInformation.getAttribute(key)
    }
    
    var processSET: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        let key = _self.getParam(XML, par: &par)
        let value = _self.getParam(XML, par: &par)
        
        _self.variables[key] = value
        
        return ""
    }
    
    var processGET: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        let key = _self.getParam(XML, par: &par)
        let value = _self.variables[key]
        if (value==nil) {
            return ""
        }
        return value!
    }
    
    var processVIDEOURL: ((_self: cXmlConverter, XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
    
        var par = _par.componentsSeparatedByString(":")
        
        // sanity check
        if _self.pmsId == nil {
            return "[[VIDEOURL - pmsId not initialised]]"
        }
        
        if let video = _self.getNode(XML, par: &par) {
            var res = getVideoPath(video, partIx: 0, pmsId: _self.pmsId!, pmsPath: _self.pmsPath)  // todo: 0 - multi-part video
            
            // XML safe?
            res = res.stringByReplacingOccurrencesOfString("&", withString: "&amp;")  // must be first
            res = res.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
            res = res.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
            
            return res
        }
        return "[[VIDEOURL - node <video> not found]]"
    }

    var processIMAGEURL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
    
        var par = _par.componentsSeparatedByString(":")
        let key = _self.getKey(XML, par: &par)
        // todo: transcoding, real implemenattion of getPMSAdr()
        let res = getPMSAdr(_self.pmsId!, PMSPath: key)  // todo: relative path in key?
        return res
    }

    var processEVAL: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
    
        var par = _par.componentsSeparatedByString(":")
        let param = _self.getParam(XML, par: &par)
        let expr = NSExpression(format: param)
        let res = expr.expressionValueWithObject(nil, context: nil)
        
        return String(res)
    }

    var processCHK: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
    
        var par = _par.componentsSeparatedByString(":")
        let param = _self.getParam(XML, par: &par)
        let check = NSPredicate(format: param)
        let res = check.evaluateWithObject(nil)
        if (res==true) {
            return "true"
        }
        return ""
    }
    
    var processTEXT: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in

        return _par  // localize - get translated string
    }
    
    var processSETTING: ((_self: cXmlConverter,XML: XMLIndexer?, par: String) -> String)? = {
        _self, XML, _par in
        
        var par = _par.componentsSeparatedByString(":")
        let param = _self.getParam(XML, par: &par)

        return settings.getSetting(param)
    }
    
    

    // unknown command - replace brackets to mark in processed
    func processUnknown(token: String) -> String {
        return "[[" + token + "]]"
    }
    
    




// main converter loop, recursiv
/*
while True:
.   cmd_ix = getInnerBrackets(f,0)
.   if not cmd_ix:
.   .     break
.   cmd = f[cmd_ix[0]: cmd_ix[1]+1]
.   print "CMD:", cmd
.
.   if cmd.startswith("<COPY("):
.   .   # get body
.   .   body_ix = getBalancedBrackets(f,cmd_ix[1])
.   .   body = f[body_ix[0]: body_ix[1]+1]
.   .   res = processCopy(cmd, body)
.   .   # replace command & body with processed string
.   .   f = f[:cmd_ix[0]]+ res +f[body_ix[1]+1:]
.   .   print f
.    else: # if cmd.startswith("<VAL"):
.   .   res = processVal(cmd)
.   .   # replace string
.   .   f = f[:cmd_ix[0]]+ res +f[cmd_ix[1]+1:]
.   .   print f
*/
    func convert(var str: String, xmlSection: XMLIndexer?) -> String {
        var cmd_range: Range<String.Index>?
        var _range: Range<String.Index>
        var cmd, token, par, head, tail, res, _str: String
        
        while true {
            cmd_range = getBalancedBrackets(str, open:"{{", close:"}}")
            if cmd_range==nil { break }
            cmd = str.substringWithRange(cmd_range!)
            
            _str = cmd.substringFromIndex(cmd.startIndex.advancedBy(2))  // skip {{
            _range = _str.rangeOfString("(")!  // find (
            token = _str.substringToIndex(_range.startIndex)
            
            _str = cmd.substringToIndex(cmd.endIndex.advancedBy(-3))  // skip )}}
            _range = _str.rangeOfString("(")!  // find (
            par = _str.substringFromIndex(_range.endIndex)  // par.componentsSeparatedByString(":")  // array of parameters
            
            if (processStructure.indexForKey(token) != nil) {
                // get body
                var body_range: Range<String.Index>?
                body_range = getBalancedBrackets(str,
                    pos: str.startIndex.distanceTo(cmd_range!.endIndex),
                    open: "{{", close:"}}")
                _range.startIndex = body_range!.startIndex.advancedBy(2)  // skip {{
                _range.endIndex = body_range!.endIndex.advancedBy(-2)  // cut }}
                _str = str.substringWithRange(_range)
                // process parameters in responsibility of functions - to work with pre- vs post-conditions (eg. IF vs CUT)
                // process token
                res = processStructure[token]!(_self: self, XML: xmlSection, par: par, body: _str)
                // replace cmd & body with generated string
                head = str.substringToIndex(cmd_range!.startIndex)
                tail = str.substringFromIndex(body_range!.endIndex)
                str = head + res + tail
            } else if (processAttrib.indexForKey(token) != nil) {
                // recursively process parameters
                par = self.convert(par, xmlSection: xmlSection)
                // process token
                res = processAttrib[token]!(_self: self, XML: xmlSection, par: par)
                // replace cmd with generated string
                head = str.substringToIndex(cmd_range!.startIndex)
                tail = str.substringFromIndex(cmd_range!.endIndex)
                str = head + res + tail
            } else {
                // mark unknown token
                res = processUnknown(token)
                head = str.substringToIndex(cmd_range!.startIndex)
                tail = str.substringFromIndex(cmd_range!.endIndex)
                str = head + res + tail
            }
        }
        return str
    }
    
    
    func doIt() -> String {
        var res: String

        res =  convert(template, xmlSection: nil)
        return res
    }

}