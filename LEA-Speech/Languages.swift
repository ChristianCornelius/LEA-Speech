//
//  Languages.swift
//  LEA-Speech
//
//  Created by Christian Cornelius on 24.02.26.
//

// 🔥 SPRACHEN ENUM
enum Language: String, CaseIterable {
    case albanian = "sq-AL"
    case arabic = "ar-SA"
    case armenian = "hy-AM"
    case azeriCyrillic = "az-AZ"
    case bosnian = "bs-BA"
    case chinese = "zh-CN"
    case dari = "prs-AF"
    case english = "en-US"
    case farsi = "fa-IR"
    case french = "fr-FR"
    case georgian = "ka-GE"
    case hindi = "hi-IN"
    case kurmanji = "kmr-TR"
    case macedonian = "mk-MK"
    case pashto = "ps-AF"
    case portuguese = "pt-BR"
    case punjabi = "pa-IN"
    case romanian = "ro-RO"
    case russian = "ru-RU"
    case serbian = "sr-RS"
    case somali = "so-SO"
    case sorani = "ku-TR"
    case spanish = "es-ES"
    case tamil = "ta-IN"
    case tigray = "ti-ET"
    case turkish = "tr-TR"
    case ukrainian = "uk-UA"
    case urdu = "ur-PK"
    case vietnamese = "vi-VN"
    
    var displayName: String {
        switch self {
        case .albanian:
            return "🇦🇲 Albanisch"
        case .arabic:
            return "🇦🇪 Arabisch"
        case .armenian:
            return "🇦🇲 Armenisch"
        case .azeriCyrillic:
            return "🇦🇿 Aserbaidschanisch"
        case .bosnian:
            return "🇧🇦 Bosnisch"
        case .chinese:
            return "🇨🇳 Chinesisch"
        case .dari:
            return "🇩🇿 Dari"
        case .english:
            return "🇬🇧 Englisch"
        case .farsi:
            return "🇮🇷 Farsi"
        case .french:
            return "🇫🇷 Französisch"
        case .georgian:
            return "🇬🇪 Georgisch"
        case .hindi:
            return "🇮🇳 Hindi"
        case .kurmanji:
            return "🇹🇷 Kurmandschi"
        case .macedonian:
            return "🇲🇰 Mazedonisch"
        case .pashto:
            return "🇦🇫 Paschtu"
        case .punjabi:
            return "🇵🇰 Punjabi"
        case .portuguese:
            return "🇧🇷 Portugiesisch"
        case .romanian:
            return "🇷🇴 Rumänisch"
        case .russian:
            return "🇷🇺 Russisch"
        case .serbian:
            return "🇷🇸 Serbisch"
        case .somali:
            return "🇸🇴 Somali"
        case .sorani:
            return "🇸🇩 Sorani"
        case .spanish:
            return "🇪🇸 Spanisch"
        case .tamil:
            return "🇮🇳 Tamil"
        case .tigray:
            return "🇹🇷 Tigrinisch"
        case .turkish:
            return "🇹🇷 Türkisch"
        case .ukrainian:
            return "🇺🇦 Ukrainisch"
        case .urdu:
            return "🇮🇳 Urdu"
        case .vietnamese:
            return "🇻🇳 Vietnamesisch"
        }
    }
}
