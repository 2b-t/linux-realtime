# Real-time Linux

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - March 2023)



## 1. Introduction

Task scheduling on standard operating systems is to some extent non-deterministic, meaning one cannot give a guaranteed - mathematically provable - upper bound for the execution time. This is somewhat desired for most applications as this increases throughput but for any real-time system one wants to be able to give such an upper bound that a given task will never exceed. Rather than executing something as fast as possible the aim is to **execute tasks consistently**, in a deterministic fashion: What matters is the **worst case latency** rather than the average latency. There are different approaches for rendering (Linux) operating systems real-time capable. These will be discussed in the next section. An introduction to real-time operating systems can be found [here](https://www.youtube.com/watch?v=4UY7hQjEW34) and [here](https://www.youtube.com/watch?v=w3yT8zJe0Uw). [This NASA conference paper](https://ntrs.nasa.gov/citations/20200002390) discusses challenges they encountered with Linux as a real-time operating system. In case you are interested in how the Linux kernel and scheduler works under the hood I recommend reading [this guide](https://wxdublin.gitbooks.io/deep-into-linux-and-beyond/content/index.html) written by someone who is much more knowledgeable on this topic than I am. The topic also discusses load balancing on multi-core architectures.



## 2. Real-time Linux: Dual and single kernel approaches

When talking about real-time kernels one differentiates between single kernel approaches, like [`PREEMPT_RT`](https://wiki.linuxfoundation.org/realtime/start), and [dual-kernel approaches](https://linuxgizmos.com/real-time-linux-explained/), such as [Xenomai](https://en.wikipedia.org/wiki/Xenomai). You can use real-time capable Dockers in combination with all of them to produce real-time capable systems but the approaches differ. Clearly this does not depend on the Docker itself but on the **underlying host system**, meaning you still have to properly configure the host system, likely re-compiling its kernel.

### 2.1 Dual kernel real-time Linux

**Dual kernel** approaches predate single-kernel ones by several years. In this case a **separate real-time micro-kernel runs in parallel to the traditional Linux kernel**, adding a layer between the hardware and the Linux kernel that handles the real-time requirements. The real-time code is given priority over the [user space](https://ubuntu.com/blog/industrial-embedded-systems) which is only allowed to run if no real-time code is executed. The following two dual-kernel approaches are commonly used:

- [**RTAI** (Real-time Application Interface)](https://www.rtai.org/) was developed by the Politecnico di Milano. One has to program in kernel space instead of the user space and therefore can't use the standard C libraries but instead must use special libraries that do not offer the full functionality of its standard counterparts. The interaction with the user space is handled over special interfaces, rendering programming much more difficult. New drivers for the micro-kernel have to be developed for new hardware making the code always lack slightly behind. For commercial codes also licensing might be an issue as kernel modules are generally licensed under the open-source Gnu Public License (GPL).
- With the [**Xenomai**](https://xenomai.org/documentation/xenomai-3/html/xeno3prm/index.html) real-time operating system it has been tried to improve the separation between kernel and user space. The programmer works in user space and then abstractions, so called skins are added that emulate different APIs (e.g. that implement a subset of Posix threads) which have to be linked against when compiling. Xenomai processes start like any normal Linux application. After this initial initialization phase they can declare themselves as real-time. After this one loses access to Linux services and drivers and has to use specific device drivers for Xenomai. As a result an application needs to be split into real-time and non-real-time parts and a real-time device driver has to be available or likely to be developed.

### 2.2 Single kernel real-time Linux

While having excellent real-time performance the main disadvantage of dual-kernel approaches is the inherent complexity. As [stated by Jan Altenberg](https://www.youtube.com/watch?v=BKkX9WASfpI) from the German embedded development firm [Linutronix](https://linutronix.de/), one of the main contributors behind `PREEMPT_RT`:

*“The problem is that someone needs to maintain the microkernel and support  it on new hardware. This is a huge effort, and the development  communities are not very big. Also, because Linux is not running directly on the hardware, you need a  hardware abstraction layer (HAL). With two things to maintain, you’re  usually a step behind mainline Linux development.”*

This drawback has led to different developments trying to patch the existing Linux kernel by modifying scheduling in Linux itself, so called **single-kernel** systems. The **kernel itself is adapted** to be real-time capable.

By **default** the Linux kernel can be [compiled with different levels of preempt-ability](https://help.ubuntu.com/lts/installation-guide/amd64/install.en.pdf#page=98) (see e.g. [Reghenzani et al. - "The real-time Linux kernel: a Survey on PREEMPT_RT"](https://re.public.polimi.it/retrieve/handle/11311/1076057/344112/paper.pdf#page=8)):

- `PREEMPT_NONE` has no way of forced preemption
- `PREEMPT_VOLUNTARY` where preemption is possible in some locations in order to reduce latency
- `PREEMPT` where preemption can occur in any part of the kernel (excluding [spinlocks](https://en.wikipedia.org/wiki/Spinlock) and other critical sections)

These can be combined with the feature of [control groups (`cgroups` for short)](https://man7.org/linux/man-pages/man7/cgroups.7.html) by setting [`CONFIG_RT_GROUP_SCHED=y` during kernel compilation](https://stackoverflow.com/a/56189862/9938686), which reserves a certain fraction of CPU-time for processes of a certain (user-defined) group. This seems to be though connected to [high latency spikes](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index#further_considerations), something that can be observed with control groups by means of [`cyclicytest`s](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start).

**`PREEMPT_RT`** developed from `PREEMPT` and is a set of patches that aims at making the kernel fully preemptible, even in critical sections (`PREEMPT_RT_FULL`). For a more detailed explanation refer to [this Ubuntu in depth-guide](https://ubuntu.com/blog/real-time-kernel-technical). For this purpose e.g. [spinlocks are largely replaced by mutexes](https://wiki.linuxfoundation.org/realtime/documentation/technical_details/sleeping_spinlocks). This way there is no need for kernel space programming - instead one can use the standard C and Posix threading libraries. In mid 2021 Linux lead developer Linus Torvalds [merged 70 of the outstanding 220 patches](https://linutronix.de/news/The-PREEMPT_RT-Locking-Code-Is-Merged-For-Linux-5.15) into the Linux mainline. In the near future `PREEMPT_RT` should be available by default to the Linux community without needing to patch the system, guaranteeing also the maintenance of the patch. For a more detailed overview have a look at [this](https://bootlin.com/doc/training/preempt-rt/preempt-rt-slides.pdf) presentation as well as the Ubuntu introductory series (see [this webinar](https://ubuntu.com/engage/an-introduction-to-real-time-linux-part-i) as well as [this blog post](https://ubuntu.com/blog/real-time-kernel-technical)). One potential problem with this is that the kernel drivers are not necessarily developed with real-time constraints in mind.

`PREEMPT_RT` is widely used in robotics:

- [SpaceX](https://www.reddit.com/r/spacex/comments/gxb7j1/comment/ft6g3dg) runs it on their onboard computers
- Robotic manufacturers like [Franka Emika](https://frankaemika.github.io/docs/installation_linux.html), [Universal Robots](https://github.com/UniversalRobots/Universal_Robots_ROS_Driver/blob/master/ur_robot_driver/doc/real_time.md) and [Toyota](https://robomechjournal.springeropen.com/articles/10.1186/s40648-019-0132-3) use it for the control computers of their robots. In particular quadrupeds such as the [MIT Mini Cheetah](https://dspace.mit.edu/bitstream/handle/1721.1/126619/IROS.pdf?sequence=2&isAllowed=y) are commonly using it.
- [National Instruments (NI)](https://www.ni.com/en/shop/linux/introduction-to-ni-linux-real-time.html) uses it on a couple of their controllers
- [LinuxCNC](https://www.linuxcnc.org/) (originally developed by NIST) uses it for numeical control of CNC machines
- It is commonly used with the [nVidia Jetson](https://docs.nvidia.com/jetson/archives/r35.1/DeveloperGuide/text/SD/Kernel/KernelCustomization.html) platform

It is important to note that installing the real-time patch only partially resolves the problem. There are [multiple **scheduling policies**](https://man7.org/linux/man-pages/man7/sched.7.html) available that will largely impact the real-time performance of the system. The scheduler is the kernel component that decides which thread should be executed by the CPU next. Each **thread** has its own **scheduling policy** as well as its **scheduling priority**. The scheduler maintains a list of all threads that should be run and their priority. First the scheduler will look at the priority and the scheduling policy will determine where this thread will be inserted in the list of threads with equal static priority and how it will be moved inside that list.

The commonly available scheduling policies are:

- `SCHED_OTHER`: [Completely fair scheduler](https://en.wikipedia.org/wiki/Completely_Fair_Scheduler), not real-time capable, generally the default scheduling policy
- `SCHED_DEADLINE`: Earliest-deadline-first scheduling

- **`SCHED_FIFO`**: First-in-first-out scheduling without time slicing. This is generally used for real-time applications
- `SCHED_RR`: Enhancement of `SCHED_FIFO` with time slicing

Check the section on user code to see how to set a scheduling policy from inside the code.

### 2.3 Performance comparison

Which of two approaches is faster has not been completely settled and is still disputed. Most of the available literature on this topic claims that Xenomai is slightly faster. Jan Altenberg though claims that he could not replicate these studies: *"I figured out that most of the time PREEMPT_RT was poorly configured. So we brought in both a Xenomai expert and a PREEMPT_RT expert, and let them configure their own  platforms.”*  [Their tests](https://www.youtube.com/watch?v=BKkX9WASfpI) show that the maximum thread wake-up time is of similar magnitude while the average is slightly slower when comparing real-world scenarios in userspace.

In any case I think that having a slight edge on performance is not worth the additional burden of writing separate real-time and non-real-time code for most people: It just makes the code harder to maintain and less portable. In my opinion most real-time code should be executable also on another system and not tie itself to a specific platform: In the long run maintainability is much more important than a slightly better real-time performance. Finally from my experience real-time performance is much more impacted by the code that you are running (e.g. memory allocation, timing functions, algorithms) than by the kernel itself. So unless you really know what you are doing `PREEMPT_RT` should actually never be a limiting factor.
