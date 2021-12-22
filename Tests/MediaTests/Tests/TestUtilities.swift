//
//  File.swift
//  
//
//  Created by Jonathan Long on 12/22/21.
//

import Foundation

struct TestMedia {
    
    enum MediaError: Error {
        case mediaDoesNotExist
    }
    
    static var testAudioFileURL: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "testaudio", withExtension: "m4a") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
    
    static var testMovieFileURL: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "testmovie", withExtension: "mov") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
    
    static var testImageURL: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "testImage", withExtension: "png") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
    
    static var testSpokenWordAudio: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "ModerElectroAcoustics", withExtension: "m4a") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
    
    static var testMovieWithStringMetadata: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "testMovieWithStringTimedMetadata", withExtension: "mov") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
    
    static var testMovieWithImageMetadata: URL {
        get throws {
            guard let URL = Bundle.module.url(forResource: "testMovieWithTimedMetadata", withExtension: "mov") else {
                throw MediaError.mediaDoesNotExist
            }
            return URL
        }
    }
}
