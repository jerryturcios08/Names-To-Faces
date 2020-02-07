//
//  ViewController.swift
//  Names To Faces
//
//  Created by Jerry Turcios on 1/12/20.
//  Copyright © 2020 Jerry Turcios. All rights reserved.
//

import LocalAuthentication
import UIKit

class ViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var people = [Person]()
    var loginLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = AppColors.spaceGray
        collectionView.backgroundColor = AppColors.spaceGray

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPerson))
        navigationItem.leftBarButtonItem?.isEnabled = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .plain, target: self, action: #selector(authenticateUser))
    }

    // MARK: - Auth/Storage methods

    @objc func authenticateUser() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Identify yourself!"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
                [weak self] success, error in

                DispatchQueue.main.async {
                    if success {
                        self?.loadStoredPeople()
                    } else {
                        let ac = UIAlertController(
                            title: "Authentication failed",
                            message: "You could not be verified; please try again.",
                            preferredStyle: .alert
                        )

                        ac.addAction(UIAlertAction(title: "Okay", style: .default))
                        self?.present(ac, animated: true)
                    }
                }
            }
        } else {
            if passwordIsStored() {
                let ac = UIAlertController(title: "Login", message: nil, preferredStyle: .alert)

                ac.addTextField { textField in
                    textField.placeholder = "Password"
                    textField.isSecureTextEntry = true
                }

                ac.addAction(UIAlertAction(title: "Enter", style: .default) { [weak self, weak ac] _ in
                    let enteredPassword = ac?.textFields?[0].text
                    let storedPassword = KeychainWrapper.standard.string(forKey: "Password")

                    // Checks if the user entered the correct password
                    if enteredPassword == storedPassword {
                        self?.dismiss(animated: true)
                        self?.loadStoredPeople()
                    } else {
                        let ac = UIAlertController(
                            title: "Error",
                            message: "The password you entered is not correct. Please try again.",
                            preferredStyle: .alert
                        )

                        ac.addAction(UIAlertAction(title: "Okay", style: .default))
                        self?.present(ac, animated: true)
                    }
                })

                ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(ac, animated: true)
            } else {
                let ac = UIAlertController(title: "Create a new password", message: nil, preferredStyle: .alert)

                ac.addTextField { textField in
                    textField.placeholder = "Enter password"
                    textField.isSecureTextEntry = true
                }

                ac.addTextField { textField in
                    textField.placeholder = "Confirm password"
                    textField.isSecureTextEntry = true
                }

                ac.addAction(UIAlertAction(title: "Enter", style: .default) { [weak self, weak ac] _ in
                    let enteredPassword = ac?.textFields?[0].text
                    let confirmedPassword = ac?.textFields?[1].text

                    // Saves the password if the confirmation password is the same and the entered password
                    // has more than three characters
                    if enteredPassword == confirmedPassword && enteredPassword!.count > 3 {
                        KeychainWrapper.standard.set(enteredPassword!, forKey: "Password")

                        self?.dismiss(animated: true)
                        self?.loadStoredPeople()
                    } else {
                        let ac = UIAlertController(
                            title: "Error",
                            message: "The passwords are not the same",
                            preferredStyle: .alert
                        )

                        ac.addAction(UIAlertAction(title: "Okay", style: .default))
                        self?.present(ac, animated: true)
                    }
                })

                ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(ac, animated: true)
            }
        }
    }

    func passwordIsStored() -> Bool {
        let password = KeychainWrapper.standard.string(forKey: "Password") ?? ""

        // Returns false if no password could be found
        if password.isEmpty {
            return false
        }

        return true
    }

    func loadStoredPeople() {
        navigationItem.leftBarButtonItem?.isEnabled = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign out", style: .plain, target: self, action: #selector(savePeopleArray))

        if let retrievedPeople = KeychainWrapper.standard.data(forKey: "People") {
            if let decodedData = try? JSONDecoder().decode([Person].self, from: retrievedPeople) {
                people = decodedData
                collectionView.isHidden = false
                collectionView.reloadData()
            }
        }
    }

    @objc func savePeopleArray() {
        guard collectionView.isHidden == false else { return }
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .plain, target: self, action: #selector(authenticateUser))

        if let encodedData = try? JSONEncoder().encode(people) {
            KeychainWrapper.standard.set(encodedData, forKey: "People")
            collectionView.isHidden = true
        }
    }

    // MARK: - Functionality methods

    @objc func addNewPerson() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        }

        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }

        let imageName = UUID().uuidString
        let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)

        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: imagePath)
        }

        let person = Person(name: "Unknown", image: imageName)
        people.append(person)

        collectionView.reloadData()
        dismiss(animated: true)
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // MARK: - Collection view methods

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return people.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Person", for: indexPath) as? PersonCell else {
            fatalError("Unable to dequeue PersonCell")
        }

        let person = people[indexPath.item]
        cell.name.text = person.name

        let path = getDocumentsDirectory().appendingPathComponent(person.image)
        cell.imageView.image = UIImage(contentsOfFile: path.path)

        cell.imageView.layer.borderColor = UIColor.init(white: 0, alpha: 0.3).cgColor
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.cornerRadius = 3
        cell.layer.cornerRadius = 7

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let person = people[indexPath.item]

        let ac = UIAlertController(title: "Person action", message: "Please select an option for the current person", preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Delete", style: .destructive) {
            [weak self] _ in

            // Checks if there exists a person at the selected index
            if let indexOfPerson = self?.people.firstIndex(of: person) {
                self?.people.remove(at: indexOfPerson)

                // Perform deletion using the index path of the selected item
                self?.collectionView.performBatchUpdates({
                    self?.collectionView.deleteItems(at: [indexPath])
                }, completion: { _ in
                    self?.collectionView.reloadItems(at: (self?.collectionView.indexPathsForVisibleItems)!)
                })
            }
        })

        ac.addAction(UIAlertAction(title: "Edit", style: .default) {
            [weak self] _ in

            let editAc = UIAlertController(title: "Rename person", message: nil, preferredStyle: .alert)
            editAc.addTextField()

            editAc.addAction(UIAlertAction(title: "Okay", style: .default) {
                [weak self, weak editAc] _ in

                guard let newName = editAc?.textFields?[0].text else { return }
                person.name = newName

                self?.collectionView.reloadData()
            })

            editAc.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self?.present(editAc, animated: true)
        })

        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
}
