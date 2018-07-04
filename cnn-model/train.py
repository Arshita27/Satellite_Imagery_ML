# -*- coding: utf-8 -*-
"""
Created on Thu Apr 19 17:40:27 2018

@author: arshita
"""

# -*- coding: utf-8 -*-
"""
Created on Wed Apr 18 18:40:37 2018

@author: arshita
"""
import json as simplejson
import keras
from keras.models import Sequential
from keras.layers import Dense, Conv2D,  MaxPooling2D, Flatten, BatchNormalization, AveragePooling2D, Activation, regularizers

import cv2
import os, os.path
from random import *
from matplotlib import pyplot as plt
import re
import linecache
import fileinput
import numpy as np
from sklearn.preprocessing import StandardScaler
import operator
from scipy import signal
import skimage.measure
from sklearn.model_selection import train_test_split
from keras.utils import np_utils  
from sklearn.metrics import confusion_matrix
from keras.callbacks import ModelCheckpoint, Callback
import seaborn as sns 

# #############################################################################
# #############################################################################

def path(n):
    if n == 1:
        imageDir_face = "class1"
    elif n==2:
        imageDir_face = "class2"
    elif n==3:
        imageDir_face = "class3"

    image_path_list_face = []
    valid_image_extensions = [".jpg"] #specify your vald extensions here
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
flattened_space_2 = path(2)
flattened_space_3 = path(3)

# #############################################################################
# --------------------------- Data Pre-Processing -----------------------------
# #############################################################################

tr_x_1 = np.array(flattened_space_1[0:1274])
tr_x_2 = np.array(flattened_space_2[0:1274])
tr_x_3 = np.array(flattened_space_3[0:1274])
tr_x = np.concatenate((tr_x_1, tr_x_2, tr_x_3), axis=0)
tr_x = scaler.fit_transform(tr_x) 

tr_y_1 = np.full((len(flattened_space_1[0:1274]), 1), 0)
tr_y_2 = np.full((len(flattened_space_2[0:1274]), 1), 1)
tr_y_3 = np.full((len(flattened_space_3[0:1274]), 1), 2)
tr_y = np.concatenate((tr_y_1, tr_y_2, tr_y_3), axis=0)
tr_y = np_utils.to_categorical(tr_y)

x_train, x_test, y_train, y_test = train_test_split(tr_x, tr_y, test_size=0.10, random_state=42)
x_train = x_train.reshape(-1, 200, 200, 3 )
x_test = x_test.reshape(-1, 200, 200, 3 )

print "------------------------- Input Data Loaded ---------------------------"

# #############################################################################
# -----------------------------CNN Model---------------------------------------
# #############################################################################
    

model = Sequential()
model.add(Conv2D(64, kernel_size=(11, 11), strides=(4,4), input_shape=(200,200,3) ))
model.add(Activation('relu'))
model.add(Conv2D(256, kernel_size = (5, 5), strides = (1,1)))
model.add(Activation('relu'))
model.add(MaxPooling2D(pool_size=(2, 2), strides=(2, 2)))
model.add(Conv2D(256, kernel_size = (3, 3), strides = (1,1)))
model.add(Activation('relu'))
model.add(Conv2D(256, kernel_size = (3, 3), strides = (1,1),))
model.add(Activation('relu'))
model.add(Conv2D(256, kernel_size = (3, 3), strides = (1,1)))
model.add(Activation('relu'))
model.add(Conv2D(4096, kernel_size = (6, 6), strides = (6, 6)))
model.add(Activation('relu'))
model.add(Conv2D(4096, kernel_size = (1, 1), strides = (1, 1)))
model.add(Activation('relu'))
model.add(AveragePooling2D(pool_size=(2, 2), strides=(2, 2)))
model.add(Flatten())
model.add(Dense(3, activation='softmax'))

# #############################################################################
# -----------------------------Training ---------------------------------------
# #############################################################################

# -------------------------------- Parameters ---------------------------------
lr=0.01
epochs = 100
batch_size = 32

# -----------------------------------------------------------------------------

model.compile(loss=keras.losses.categorical_crossentropy,
              optimizer=keras.optimizers.SGD(lr=lr),
              metrics=['accuracy'])

class AccuracyHistory(keras.callbacks.Callback):
    def on_train_begin(self, logs={}):
        self.acc = []

    def on_epoch_end(self, batch, logs={}):
        self.acc.append(logs.get('acc'))

history = AccuracyHistory()

# --------------------------- storing  weights --------------------------------

filepath="weights.hdf5"
checkpoint = ModelCheckpoint(filepath, monitor='val_acc', verbose=1, save_best_only=True, mode='max')
callbacks_list = [checkpoint, history]

# -----------------------------------------------------------------------------

model.fit(x_train, y_train,
          batch_size=batch_size,
          epochs=epochs,
          verbose=1,
          validation_data=(x_test, y_test),
          callbacks=callbacks_list)

# ----------------------- storing Model in JSON -------------------------------

model_json = model.to_json()
with open("model.json", "w") as json_file:
    json_file.write(simplejson.dumps(simplejson.loads(model_json), indent=4))
print "finish"

# ------------------------------- evaluating ----------------------------------
         
score = model.evaluate(x_test, y_test, verbose=0)

print("Pre Processing: StandardScaler")
print("No of Epochs: ", epochs)
print("Batch size: ", batch_size)
print("Activation: RELU, Softmax")
print("Optimizer: SGD")
print("Learning Rate: ", lr)
print("--------------Test Results:------------")
print('Test loss:', score[0])
print('Test accuracy:', score[1]) 
plt.plot(range(1,epochs+1), history.acc)
plt.xlabel('Epochs')
plt.ylabel('Accuracy')
plt.show()

# #############################################################################
# ----------------------------- Predicting ------------------------------------
# #############################################################################

preds = model.predict(x_test, verbose=0)

t=np.zeros(len(preds))
for i in range(len(preds)):
    t[i] = np.argmax(preds[i])

l = np.zeros(len(y_test))
for i in range(len(y_test)):
    for j in range(3):
        if y_test[i][j]==1:
            l[i]=j
            
# --------------------------- Confusion Matrix --------------------------------

final = (confusion_matrix(l, t))
sns.set()
ax = sns.heatmap(final)


