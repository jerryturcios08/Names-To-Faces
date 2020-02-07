//
//  Person.swift
//  Names To Faces
//
//  Created by Jerry Turcios on 1/13/20.
//  Copyright © 2020 Jerry Turcios. All rights reserved.
//

import UIKit

class Person: NSObject, Codable {
    var name: String
    var image: String

    init(name: String, image: String) {
        self.name = name
        self.image = image
    }
}
