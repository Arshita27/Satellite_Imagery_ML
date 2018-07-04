# -*- coding: utf-8 -*-
"""
Created on Fri Apr 20 11:26:59 2018

@author: arshita
"""

from keras.models import model_from_json

import cv2
import os, os.path
import linecache
import numpy as np
from sklearn.preprocessing import StandardScaler

from sklearn.metrics import confusion_matrix


def path(n):
    if n == 1:
        imageDir_face = "test/test_malawi_images"
    image_path_list_face = []
    valid_image_extensions = [".jpg"] 
    valid_image_extensions = [item.lower() for item in valid_image_extensions]
    
    image_list_face = [] 
    for root, dirs, files in os.walk(imageDir_face):
        for file in files:
            with open(os.path.join(root, file), "r") as auto:
                extension = os.path.splitext(file)[1]
                if extension.lower() not in valid_image_extensions:
                    continue
                image_list_face.append(os.path.join(root, file))
   
    flattened_space_face = []
    for imagePath in image_list_face:
        image = cv2.imread(imagePath)
        image = cv2.resize(image,(200,200))
        flattened = image.flatten()
        flattened_space_face.append(flattened)        
    return flattened_space_face
        
               
# #############################################################################
# --------------------------- Reading Files -----------------------------------
# #############################################################################
scaler = StandardScaler()

flattened_space_1 = path(1)
tr_x_1 = np.array(flattened_space_1)
x_test = scaler.fit_transform(tr_x_1) 
x_test = x_test.reshape(-1, 200, 200, 3 )

y_test_file = "test/test_malawi_classes.txt"
 
y_test = np.zeros((len(tr_x_1)))
with open(y_test_file,'r') as test_file:
    for num, line in enumerate(test_file,1):                     
        y=linecache.getline(y_test_file,(num))
        z = y.strip().split(",")
        for i in range (len(z)):
            y_test[num-1] = z[i] 
                      
print "------------------------- Input Data Loaded ---------------------------"


# #############################################################################
# ----------------------------- Predicting ------------------------------------
# #############################################################################

json_file = open('model.json', 'r')
loaded_model_json = json_file.read()
json_file.close()
loaded_model = model_from_json(loaded_model_json)

loaded_model.load_weights("weights.hdf5")
print("Loaded model from disk")

loaded_model.compile(loss='binary_crossentropy', optimizer='adam', metrics=['accuracy'])
preds = loaded_model.predict(x_test, verbose=0)


# #############################################################################
# ----------------------------- Accuracuy- ------------------------------------
# #############################################################################

t=np.zeros(len(preds))
for i in range(len(preds)):
    t[i] = np.argmax(preds[i])
print t

count=0
for i in range(len(y_test)):
    if y_test[i]==t[i]:
        count=count+1
        
print count
print ("Accuracy", (float(count))/len(preds))


final = (confusion_matrix(y_test, t))
import seaborn as sns 
sns.set()
ax = sns.heatmap(final)