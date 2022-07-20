FROM amazon/aws-iot-greengrass:latest
RUN yum -y install git
RUN yum -y install /usr/bin/ab
RUN echo $(( $RANDOM % 10 + 20 )) > /var/gpu_load_fb
RUN echo $(( $RANDOM % 10 + 80 )) > /var/gpu_inference_fb
RUN chmod 777 /var/gpu_load_fb
RUN chmod 777 /var/gpu_inference_fb