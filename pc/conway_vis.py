import os,sys,time
import serial
from time import sleep
from threading import Thread
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import colors
import matplotlib.animation as animation
import matplotlib.cm as cm

os.system('cls' if os.name == 'nt' else 'clear')
print("Starting...")
ON = 255
OFF = 0
vals = [ON, OFF]
N = 10
gridData = np.zeros((N,N))
grid = np.random.choice(vals, N*N, p=[0.2, 0.8]).reshape(N, N)

fig = plt.figure()
ax1 = fig.add_subplot(121)
#ax1.imshow(gridData, interpolation='nearest', cmap=cm.Greys_r)
#plt.draw()
#plt.pause(0.001)



ser = serial.Serial("com6",9600,timeout=0.01)
done = 0
command = '0'
rowCounter = 0

while True:
    if ser.inWaiting() == 0 and done == 0:
        print("com6 - nothing waiting - encode command")
        #data = ['254','234','176','123','215','123','008','054','080','012']
        data1 = [254,234,176,123,215,123,8,54,80,12]
        data = bytearray(data1)
        ser.write(data)

        
        #str1 =  ''
        #for x in data:
        #    str1 += x
        #ser.write(str1.encode())
        sleep(0.03)
        done = 1
    elif ser.inWaiting() > 0:
        #print("com1 - receive data from readline")
        received_data = ser.readline()
        
        if done == 0:
            print("com1 - done and exit")
        else:
            #a[rowCounter,0] = received_data.decode()[0]
            if (len(received_data.decode()) > 10):
                for j in range(10):
                    if (received_data.decode()[j] == '0'):
                        gridData[rowCounter,j] = 0
                    elif (received_data.decode()[j] == '1'):
                        gridData[rowCounter,j] = 1
            #print (received_data.decode())
            
            if (rowCounter < N):
                print(gridData[rowCounter,:])
                
            rowCounter = rowCounter + 1
            if rowCounter == N+1:
                #plot here
                ax1.imshow(gridData, interpolation='nearest', cmap=cm.Greys_r)
                plt.draw()
                plt.pause(0.001)
                rowCounter = 0
                
        sleep(0.1)
    else:
        # TODO: may need to remove
        print("com6 - no data waiting")
        c = ''
        sleep(0.5)
        os.system('cls' if os.name == 'nt' else 'clear')
        if c == '':
            c = '00'
            ser.write(c.encode())
        sleep(0.05)
        #command = '0'
        
while command != '3':
    command = input("{} (1) Step   (2) Input cell states    (3) Exit\n".format(command))
    done = 0
    while command == '1':
        if ser.inWaiting() == 0 and done == 0:
            print("com1 - nothing waiting - encode command")
            ser.write(command.encode())
            sleep(0.03)
            done = 1
        if ser.inWaiting() > 0:
            print("com1 - receive data from readline")
            received_data = ser.readline()
            if received_data.decode() == 'done':
                command = '0';
                print("com2 - done and exit")
            else:
                print (received_data.decode())
            sleep(0.03)
        else:
            # TODO: may need to remove
            print("com1 - no data waiting")
            sleep(0.3)
            #command = '0'
    while command == '2':
        if ser.inWaiting() == 0 and done == 0:
            done = 1
            print("com2 - nothing waiting - encode command and data")
            ser.write(command.encode())
            sleep(0.02)
            data = ['1','6','8','4','0','9','8','7','8','12']
            str1 =  ''
            for x in data:
                str1 += x
            ser.write(str1.encode())
            sleep(0.03)
        if ser.inWaiting() > 0:
            print("com2 - receive data and print")
            received_data = ser.readline()
            if received_data.decode() == 'done':
                print("com2 - done and exit")
                command = '0';
            else:
                print (received_data.decode())
            sleep(0.03)
        else:
            # TODO: may need to remove
            print("com2 - no data")
            sleep(0.3)
            #command = '0'
    while command != '0' and command != '1' and command != '2':
        if ser.inWaiting() > 0:
            received_data = ser.readline()
            if received_data.decode() == 'done':
                command = '0';
            else:
                print (received_data.decode())
            sleep(0.03)
        else:
            sleep(0.03)
            command = '0'



    
    
    #step
    if command == '1':
        while True:
            if ser.inWaiting() > 0:
                received_data = ser.readline()
                print (received_data.decode())
                sleep(0.03)
            else:
                #print ("O: {}".format(ser.out_waiting()))
                print ("I: {}".format(ser.inWaiting()))
                c = input()
                ser.write(c.encode())
                sleep(0.03)
    # input cell states            
    elif command == '2':
        c = '22'
        ser.write(c.encode())
        sleep(1)
        print ("#: {}".format(ser.inWaiting()))
        sleep(1)
        print ("#: {}".format(ser.inWaiting()))
        sleep(1)
        print ("#: {}".format(ser.inWaiting()))
        while ser.inWaiting() > 0:
            received_data = ser.readline()
            print (received_data.decode())
            sleep(0.06)
