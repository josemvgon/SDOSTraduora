//
//  File.swift
//  
//
//  Created by Oleg Tverdyy on 27/5/21.
//

import Foundation

final public class LangClass {
    public static let shared = LangClass()
    
    private init() { }
    
    private var cleanDirectory = false
    
    private var langs: [String]?
    
    public func langs(project: String, server: String?) throws {
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = NSMutableURLRequest(url: URL(string: "\(Constants.ws.getBaseUrl(server: server))\(Constants.ws.langs(project: project))")!,
                                          cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                          timeoutInterval: 15.0)
        request.httpMethod = Constants.ws.method.GET
        request.allHTTPHeaderFields = [
            Constants.ws.headers.contentType: Constants.ws.headers.value.json,
            Constants.ws.headers.authorization: AuthClass.shared.bearer()
        ]
        
        var errorWS: Error? = nil
        let session = Constants.session
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            guard error == nil, let data = data else {
                print("[SDOSTraduora] Error al recuperar los lenguajes de las traducciones. Error: \(error!.localizedDescription)")
                errorWS = TraduoraError.langRequest(error!)
                semaphore.signal()
                return
            }
            
            if let lang = try? LangDTO(data: data) {
                print("[SDOSTraduora] Success request \(request.url?.absoluteString ?? "")")
                print(String(data: data, encoding: .utf8) ?? "")
                self.langs = lang.data.map { $0.locale.code }
            } else {
                print("[SDOSTraduora] Failed request \(request.url?.absoluteString ?? "")")
                print(String(data: data, encoding: .utf8) ?? "")
                errorWS = TraduoraError.langRequestInvalidResponseData
            }
            
            semaphore.signal()
        })
        
        dataTask.resume()
        
        semaphore.wait()
        
        if let errorWS {
            throw errorWS
        }
    }
    
    public func download(server: String?, project: String, language: String, output: String, fileName: String, label: String? = nil, format. String? = nil) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var errorWS: Error? = nil
        
        var components = URLComponents(string: "\(Constants.ws.getBaseUrl(server: server))\(Constants.ws.downloadLang(project: project, language: language, label: label))")!

        components.queryItems = [
            URLQueryItem(name: Constants.ws.query.locale, value: language),
            URLQueryItem(name: Constants.ws.query.format, value: format ?? Constants.ws.query.value.jsonNested)
        ]
        
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        let request = NSMutableURLRequest(url: components.url!,
                                          cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                          timeoutInterval: 15.0)
        request.httpMethod = Constants.ws.method.GET
        request.allHTTPHeaderFields = [
            Constants.ws.headers.contentType: Constants.ws.headers.value.octet,
            Constants.ws.headers.authorization: AuthClass.shared.bearer()
        ]
        let session = Constants.session
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            guard error == nil, let data = data else {
                errorWS = TraduoraError.downloadLangRequest(error!)
                semaphore.signal()
                return
            }
            if let items = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] {
                print("[SDOSTraduora] Success request \(request.url?.absoluteString ?? "")")
                print(String(data: data, encoding: .utf8) ?? "")
                let directoryName = "\(output)/\(language).lproj"
                print("[SDOSTraduora] Generando fichero para el idioma \(language)")
                
                let fileManager = FileManager.default
                var isDir: ObjCBool = false
                
                if !self.cleanDirectory {
                    self.cleanDirectory = true
                    try? fileManager.removeItem(atPath: "\(output)")
                }
                
                if !fileManager.fileExists(atPath: directoryName, isDirectory: &isDir) {
                    do {
                        try fileManager.createDirectory(atPath: directoryName, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        errorWS = TraduoraError.downloadLangCreateFolders(directoryName, error)
                        semaphore.signal()
                        return
                    }
                }
                
                let filePath = "\(directoryName)/\(fileName)"
                do {
                    let header = """
                    //  This is a generated file, do not edit!
                    //  Localizable.generated.strings
                    //
                    //  Generate \(items.count) keys
                    """
                    let strings = items.sorted(by: { e1, e2 in
                        e1.key < e2.key
                    }).map {
                        return "\"\($0.key)\" = \"\(self.formatLine($0.value))\";"
                    }.joined(separator: "\n")
                    try [header, strings].joined(separator: "\n\n").write(toFile: filePath, atomically: true, encoding: .utf8)
                } catch {
                    print("[SDOSTraduora] Error al generar el fichero de traducciones para el idioma \(language) en \(filePath). Error \(error.localizedDescription)")
                }
                print("[SDOSTraduora] Fichero generado para el idioma \(language) en \(filePath)")
            } else {
                print("[SDOSTraduora] Failed request \(request.url?.absoluteString ?? "")")
                print(String(data: data, encoding: .utf8) ?? "")
                let json = String(data: data, encoding: .utf8)
                errorWS = TraduoraError.downloadLangParser(language, json)
                semaphore.signal()
                return
            }
            semaphore.signal()
            
        })
        
        dataTask.resume()
        
        
        semaphore.wait()
        
        if let errorWS {
            throw errorWS
        }
    }
    
    func formatLine(_ line: String) -> String {
        
        var lineFinal = line
        
        #warning("Removed because Oysho Training App")
//        lineFinal = lineFinal.replacingOccurrences(of: "%", with: "%%")
        #warning("Added because Oysho Training App")
        lineFinal = lineFinal.replacingOccurrences(of: "%s", with: "%@")
        
        lineFinal = lineFinal.replacingOccurrences(of: "\"", with: "\\\"")
        lineFinal = lineFinal.replacingOccurrences(of: "\n", with: "\\n")
        lineFinal = lineFinal.replaceRegexNumber()
        lineFinal = lineFinal.replaceRegexDecimal()
        lineFinal = lineFinal.replaceRegexString()

        return lineFinal
    }
    
    public func getAllLangs() -> [String]? {
        langs
    }
    
}
