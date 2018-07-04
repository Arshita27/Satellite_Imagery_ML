# Combining satellite imagery and machine learning to predict poverty

This repository is an attempt to help readers dive deeper into the work done by Jean Burke, et al. in his paper ‘Combining Satellite Imagery and Machine Learning to Predict Poverty’ [link](http://science.sciencemag.org/content/353/6301/790) by building and implementing a Convolutional Neural Network. Here, you not only get a glance of the model used by Jean (which is given in his paper ‘Nighttime Light Predictions from Satellite Imagery’ [link](http://cs231n.stanford.edu/reports/2016/pdfs/423_Report.pdf)) but also implement your own CNN model with slight variations.


## Brief Introduction:
(**_Note_**: If you have read the paper and understood it completely then you can directly jump to the implementation section otherwise here is a little introduction to this project.)

Neal Jean et. al aim to help predict poverty by combining satellite Imagery and convolutional Neural Network with transfer learning. When we talk about using satellite imagery we are basically using some features hidden in these high resolution day time images that will help us make future predictions about the poverty in the area we are interested in. Now a simple question that arises is why deal with day-time images? A more direct approach that one could think off is predict Poverty using Night-time imagery from satellite. Night time images can tell us how well lit an area is and accordingly we can divide the  areas in low, mid or high poverty range. Now the problem here, as discussed by Jean too in his paper [link](http://science.sciencemag.org/content/353/6301/790), is that the night time images can be highly deceptive as a highly lit area can be covered by clouds or a low lit area may appear bright due to its surrounding area. Also a sparsely populated areas is not necessarily a low poverty area. Thus we can agree on the fact that night time images are not the best metric to calculate poverty.

Coming back to the day-time images, in earlier times scientists had to manually select the relevant features from their dataset in order to train their model called feature engineering. This process can be a tedious task as it is difficult to extract features that will be important and benefit the model. This is where Convolutional Neural Networks comes in the picture. The greatest advantage of convolutional neural networks is that they can learn appropriate features by themselves. We simply feed raw images into our CNN, and the CNN can learn how to get the right features for training our model.

Next let’s talk about Neal Jean’s paper [link](http://cs231n.stanford.edu/reports/2016/pdfs/423_Report.pdf) where he explains the model he has used.  In this paper, they begin with a CNN model pre-trained on the ImageNet dataset and then fine-tune it using satellite daytime images and nighttime light intensity data through transfer learning. If you are not familiar with transfer learning, I recommend you to go through this [link](http://cs231n.github.io/transfer-learning/). A final softmax classifier is used to predict the nighttime light intensity of the particular area. The paper further extends its goal such that the CNN features learned from the nightlights classification task can be used to predict indicators of interest to the international scientific community, such as poverty, wealth, or health outcomes.

The next section talks about my implemention of this project.

## Implementation:

I have made a few changes in the cnn model and thus trained my model to get similar results. The specifications of the entire model is given in the script __train.py__.

#### The repository consists of following folders:
1. data
2. scripts: Loading Data Set and Pre- Processing
3. cnn-model

#### Packages and Tools:


Code was written in Python 2.7.14 and R 3.4.1.

( _It is advised to use Anaconda as it gives the user the flexibility to create new environments with the preferred Python versions and also makes installation of packages easier in the respective environment_)

- Packages in Python:
 - Jupyter
 - requests
 - NumPy
 - Pandas
 - SciPy
 - scikit-learn
 - Seaborn
 - OpenCV 3.1.0

If anaconda is installed the user can run the following command given below to automatically install the python packages after installing anaconda.

> conda install jupyter requests numpy pandas scipy scikit-learn seaborn

- Install Tensorflow v1.3.0 with GPU using this [link](https://www.tensorflow.org/install/).

- Install Keras with GPU using this [link](https://keras.io/#installation).

- Packages in R:
 - R.utils
 - magrittr
 - foreign
 - raster
 - readstata13
 - plyr
 - dplyr
 - sp
 - rgdal

Install RStudio v1.1.423


[__*Note*__: You can either download the dataset and train the model from scratch by following or directly use my pre-trained model given in __'Perform predictions  with the pre-trained model'__ section. I have also prepared the input data set and saved in __data/images/__ for convenience so the pre-trained model can be run directly without any downloading or processing of images.]

#### Instructions to download satellite images

The following lets you download images that can be used to train the cnn model. Run the scripts in th eorder given below.

- Download the F182013.v4.tar file using [link](https://www.ngdc.noaa.gov/eog/data/web_data/v4composites/). Extract the .tif file and save it in __scripts__ folder.
- Run the following R code:
  1. scripts/get_coordinates.R

- Set the working directory as __scripts/__ and run the following jupyter notebooks (this process could take 2-3 hours to execute).
 1. Classification_XYZ.ipynb
 2. getting_images.ipynb

Now your __data/images__ folder should be populated with satellite images.

#### Instructions for using our cnn model for training and predictions

__Creating training data from data/images__
1. Create folders names 'class1', 'class2' and 'class3' in cnn-model
2. Take the images of class1 category of all countries in data/images and copy them to the cnn-model/class1 folder.
3. Repeat the 2nd step for class2 and class3 as well.

__Training the model and predictions__
1. Set working directory to cnn-model The model has been trained for epochs = 100 and batch_size = 32.
2. Run the script: train.py
 1. This will create a hdf5 object file with weights of the trained cnn model.
 2. This will also create a model.JSON file with the model architecture.
3. Run script:  predict.py

__Perform predictions with the pre-trained model__
1. Download the hdf5 object and model.JSON files from here
2. Save it in cnn-model folder.
3. Run script:  predict.py
