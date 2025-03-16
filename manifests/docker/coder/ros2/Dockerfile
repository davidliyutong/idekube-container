# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown

FROM ${REGISTRY}/${AUTHOR}/${NAME}:coder-base-${GIT_TAG} AS system

ARG ROS_DISTRO=jazzy

# Install the ROS2 in this container (Ubuntu 24.04)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    lsb-release \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*


# Setup sources.list
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    sh -c 'echo "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'

# Install ROS2 packages
RUN apt-get update && apt-get install -y colcon python3-rosdep python3-vcstool \
    ros-${ROS_DISTRO}-desktop-full ros-${ROS_DISTRO}-ros-gz ros-${ROS_DISTRO}-rosbridge-server ros-${ROS_DISTRO}-moveit \
    build-essential libeigen3-dev libopencv-dev libpcl-dev chrony \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

# Setup environment
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/skel/.bashrc
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.zsh" >> /etc/skel/.zshrc
ENV ROS_DISTRO=jazzy

