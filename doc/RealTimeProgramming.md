# Introduction to Real-time Programming

Author: [Tobit Flatscher](https://github.com/2b-t) (2023 - 2025)



## 0. Introduction

This guide gives an introduction into programming of real-time systems focussing on C++ and ROS 2. As such it outlines common mistakes that beginners make when starting to program real-time applications and advice to what pay attention to when programming with ROS. The ROS part is strongly influenced by the ROS 2 real-time working group presentation at [ROSCon 2023](https://docs.google.com/presentation/d/1yHaHiukJe-87RhiN8WIkncY23HxFkJynCQ8j3dIFx_w/edit#slide=id.p).

## 1. Basics

Real-time programming requires a good understanding of how computers, their operating systems and programming languages work under the hood. While you will find several books and articles, in particular from people working in high-frequency trading, that discuss advanced aspects of low-latency programming, there is only little beginner-friendly literature.

One can find a few developer checklists for real-time programming such as [this](https://lwn.net/Articles/837019/) and [this one](https://shuhaowu.com/blog/2022/01-linux-rt-appdev-part1.html). The goal of this guide is to provide a more complete checklist and important aspects to consider when programming code for low-latency. The examples make use of C++ (many of the principles should also work in C) but these paradigms apply to all programming languages:

- Take care when designing your own code and implementing your own **algorithms**:

  - Select algorithms by a low **worst-case complexity** and not a low average complexity (see also [here](https://www.cs.odu.edu/~zeil/cs361/latest/Public/averagecase/index.html)). Keep in mind though that these latency are derived from asymptotic analysis for a large number of elements and only up to a constant (which can be quite large): Two O(n) algorithms might be very different in terms of computational speed (number of instructions and CPU cycles taken), just their scaling will be similar and similarly a O(n²) algorithm might be faster for small and medium container sizes. Therefore in particular for smaller or fixed size containers it is necessary to **benchmark** the chosen algorithm. For small containers the cache locality and memory allocation of an algorithm will likely be far more important than its asymptotic scaling behavior.
  - **Split your code** into parts that have to be **real-time** and a **non real-time** part and make them communicate with lock-free programming techniques

- **Set a priority** (nice values) to your real-time thread (see [here](https://medium.com/@chetaniam/a-brief-guide-to-priority-and-nice-values-in-the-linux-ecosystem-fb39e49815e0)). `80` is a good starting point. It is not advised to use too high priorities as this might result in problems with kernel threads:

  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  ::pthread_t const current_thread {::pthread_self()}; // or t.native_handle() for an std::thread
  int policy {};
  struct ::sched_param param {};
  ::pthread_getschedparam(current_thread, &policy, &param);
  param.sched_priority = 80; // or use ::sched_get_priority_max(some_policy)
  if (::pthread_setschedparam(current_thread, policy, &param) == 0) {
    std::cout << "Set thread priority to '" << param.sched_priority << "'." << std::endl;
  } else {
    std::cerr << "Failed to set thread priority to '" << param.sched_priority << "'!" << std::endl;
  }
  ```

- Set a **scheduling policy** that fits your needs (see [here](https://man7.org/linux/man-pages/man7/sched.7.html)). **`SCHED_FIFO`** is likely the one you want to go for if you do not have a particular reason to do otherwise:
  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  ::pthread_t const current_thread {::pthread_self()};
  int policy {};
  struct ::sched_param param {};
  ::pthread_getschedparam(current_thread, &policy, &param);
  policy = SCHED_FIFO;
  if (::pthread_setschedparam(current_thread, policy, &param) == 0) {
    std::cout << "Set scheduling policy to '" << policy << "'." << std::endl;
  } else {
    std::cerr << "Failed to set scheduling policy to '" << policy << "'!" << std::endl;
  }
  ```
  
- **Pin the thread to an isolated CPU core** (which was previously isolated on the operating system). This way the process does not have to fight over resources with other processes running on the same core.

  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  constexpr int cpu_core {0};
  ::pthread_t const current_thread {::pthread_self()};
  ::cpu_set_t cpuset {};
  CPU_ZERO(&cpuset);
  CPU_SET(cpu_core, &cpuset);
  if (::pthread_setaffinity_np(current_thread, sizeof(::cpu_set_t), &cpuset) == 0) {
    std::cout << "Set thread affinity to cpu '" << cpu_core << "'!" << std::endl;
  } else {
    std::cerr << "Failed to set thread affinity to cpu '" << cpu_core << "'!" << std::endl;
  }
  ```

  This can be tested by stressing the system e.g. with `stress-ng`. In a process viewer like `htop` you should see that the unisolated cores will be fully used while the isolated CPU cores should just be running the intended code and should only be partially used:

- Dynamic memory allocation (reserving virtual and physical memory) might be slow and non-deterministic. **Avoid any form of dynamic memory allocation inside real-time code**:

  - Do not use explicit dynamic memory allocation. Use functions for **statically allocating memory before entering a real-time section** (e.g. [`std::vector<T,Alloc>::reserve`](https://en.cppreference.com/w/cpp/container/vector/reserve)).

  - Also avoid structures that are using dynamic memory allocation under the hood such as `std::string` in C++. [Mutate strings](https://www.oreilly.com/library/view/optimized-c/9781491922057/ch04.html) to eliminate temporary copies.

  - **Lock memory pages with [`mlock`](https://man7.org/linux/man-pages/man2/mlock.2.html)**. This locks the process's virtual address space into RAM, preventing that memory from being paged to the swap area:

    ```c
    #include <sys/mman.h>
    
    ::mlockall(MCL_CURRENT | MCL_FUTURE);
    ```

- Generally real-time processes need to communicate with other non real-time processes. **Do not use standard mutexes (e.g. `std::mutex`) when communicating between threads with different priorities** as this is known to potentially result in [priority inversion](https://en.wikipedia.org/wiki/Priority_inversion): A low-priority task might only run after another task with same or slightly higher priority and therefore block the high-priority task that relies on the low-priority task to complete

  - Use **lock-free programming techniques**: These are different techniques to share data between two (or more) threads without using explicit locks. The possible solution depends largely on your constraints (single or multiple producers/consumers, real-time requirements for only one thread or for all involved threads):
    - **Atomic variables** can be used for data shared in between two threads where one thread is reading and the other one is writing. This only works for data that is trivially constructible (e.g. classes that do not contain `std::vector<T>` or `std::shared_ptr<T>`) and does not contain any sort of pointers (as there will still be a race condition for the pointers). Furthermore be aware that [**atomic variables are not necessarily lock-free**](https://ryonaldteofilo.medium.com/atomics-in-c-what-is-a-std-atomic-and-what-can-be-made-atomic-part-1-a8923de1384d): They are only guaranteed to be lock-free if [`std::atomic<T>::is_always_lock_free`](https://en.cppreference.com/w/cpp/atomic/atomic/is_always_lock_free) is `true`, otherwise a mutex or a similar locking mechanism might still be used under the hood.
    - For applications that require you to share data in between a non-real-time thread and a real-time thread you can use simpler solutions such as [ROS Control's **real-time tools `RealtimeBuffer`**](https://github.com/ros-controls/realtime_tools/blob/master/include/realtime_tools/realtime_buffer.hpp). It uses a lock but it is non-blocking on the real-time side while it might block the non-real-time thread. Whether this is viable depends on whether the non-real-time thread is supposed to process only the most recent data or is supposed to process all data without any data loss.
    - Use **lock-free queues** (which for real-time applications are generally implemented as circular buffers) for large amounts of data, see e.g. [Boost Lockfree](https://www.boost.org/doc/libs/1_76_0/doc/html/lockfree.html) (which is used by [PAL statistics](https://github.com/pal-robotics/pal_statistics/blob/41649456acf079a1e598e70608ef8ea0edbf19df/pal_statistics/src/lock_free_queue.hpp#L43)), [MoodyCamel Concurrent Queue](https://github.com/cameron314/concurrentqueue) (which is used by [Data Tamer](https://github.com/PickNikRobotics/data_tamer/blob/d00554ddb9a83e4cd0ddef1810f4861cb1714bf2/data_tamer_cpp/src/data_sink.cpp#L32)) or [Atomic Queue](https://github.com/max0x7ba/atomic_queue). Most importantly **do not build your own lock-free queues** and examine their implementations closely! Many home-brew implementations (even by seasoned C++ developers) are broken in obvious or subtle ways (see e.g. Herb Sutter's articles [1](https://drdobbs.com/parallel/writing-lock-free-code-a-corrected-queue/210604448), [2](https://drdobbs.com/cpp/lock-free-code-a-false-sense-of-security/210600279), [3](https://drdobbs.com/parallel/writing-a-generalized-concurrent-queue/211601363#disqus_thread) as well as [this post](https://moodycamel.com/blog/2013/a-fast-lock-free-queue-for-c++.htm)) :
      - Solutions that do not handle ["overtaking"](https://stackoverflow.com/questions/871234/circular-lock-free-buffer) correctly if a circular buffer is used (e.g. the flawed implementation [here](https://github.com/PacktPublishing/Building-Low-Latency-Applications-with-CPP/blob/fc7061f3435009a5e8d78b2dc189c50b59317d58/Chapter4/lf_queue.h) from the book ["Building Low Latency Applications with C++"](https://www.packtpub.com/product/building-low-latency-applications-with-c/9781837639359))
      - Solutions that might work for a single producer and a single consumer (SPSC) running in two different threads but result in race conditions for the general case of multiple producers and multiple consumers (MPMC).
      - Solutions that are **not suitable for real-time applications**:
        - Being lock-free but not wait-free, see the comments [here](https://kmdreko.github.io/posts/20191003/a-simple-lock-free-ring-buffer/)
        - Relying on dynamic memory allocation, e.g. the implementation that Herb Sutter provides in [in the post above](http://www.talisman.org/~erlkonig/misc/herb+lock-free-code/p2-writing-lock-free-code--a-corrected-queue.html). One way around this limitation is to allocate the required memory using a pre-allocated memory pool instead of allocating it on the heap.
      - Suffer from the [ABA problem](https://en.wikipedia.org/wiki/ABA_problem) e.g. when relying on [compare and swap](https://en.wikipedia.org/wiki/Compare-and-swap)
      - Suffer from problems with [memory re-ordering](https://en.wikipedia.org/wiki/Memory_ordering) (due to a lack of memory barriers) that might only break the implementation on some computers depending on compiler and CPU in use
  - For just avoiding problems from priority inversion you might use [**priority inheritance mutexes**](https://www.ibm.com/docs/en/aix/7.2?topic=programming-synchronization-scheduling) e.g. by writing a wrapper around the [Linux pthread one](http://www.qnx.com/developers/docs/qnxcar2/index.jsp?topic=%2Fcom.qnx.doc.neutrino.sys_arch%2Ftopic%2Fkernel_Priority_inheritance_mutexes.html)

- Take **special care when logging from real-time processes**. Traditional logging tools generally involve mutexes and dynamic memory allocation:

  - **Do not log from real-time sections** if it can be avoided!
  - Use **dedicated real-time logging tools**, these will use asynchronous logging that passes format string pointer and format arguments from a real-time thread to non real-time thread in a lock-free way. Here a few libraries that might be helpful for this:
    - [Quill](https://github.com/odygrd/quill): An asynchronous low-latency logger for C++
    - [Data Tamer](https://github.com/PickNikRobotics/data_tamer): A logging framework that can be used with and without ROS that seemingly integrates with [Plotjuggler](https://github.com/facontidavide/PlotJuggler)
    - [PAL statistics](https://github.com/pal-robotics/pal_statistics): A real-time logging framework for ROS

- Similarly writing to files is multiple magnitudes slower than RAM access. **Do not write to files from a real-time thread!**

  - Use a dedicated **asynchronous logger** framework for it as discussed above.
  - An acceptable solution might also be a [**RAM disk**](https://www.linuxbabe.com/command-line/create-ramdisk-linux) where a part of memory is formatted with a file system and can be written to fastly.

- Make sure all of your **external library calls** respect the above criteria as well.

  - **Read their documentation and review their source code** making sure that their latencies are bounded, they do not dynamically allocate memory, do not use normal mutexes, non O(1) algorithms and whether they call IO/logging during the calls.
  - Likely you will have to refactor external code to make sure that it is usable inside real-time capable code.

- Take care when using **timing libraries**: Linux has [multiple clocks](https://linux.die.net/man/2/clock_gettime). While `CLOCK_REALTIME` might sounds like the right choice for a real-time system it is not as it can [jump forwards and backwards due to time synchronization](https://stackoverflow.com/questions/3523442/difference-between-clock-realtime-and-clock-monotonic) (e.g. [NTP](https://ubuntu.com/server/docs/network-ntp)). [You will want to **use `CLOCK_MONOTONIC`**](https://github.com/OpenEtherCATsociety/SOEM/issues/391) or `CLOCK_BOOTTIME`.

  - Take care when relying on external libraries to time events and stop times, e.g. [`std::chrono`](https://www.modernescpp.com/index.php/the-three-clocks/).

- **Benchmark** performance of your code and use tracing library to track you real-time performance. You can always test with a simulated load!

- For network applications that require to communicate over a high-speed NIC look into **kernel-bypass** instead of relying on POSIX sockets (see e.g. [here](https://blog.cloudflare.com/kernel-bypass) and [here](https://medium.com/@penberg/on-kernel-bypass-networking-and-programmable-packet-processing-799609b06898)).

A good resource for real-time programming is [this CppCon 2021 talk](https://www.youtube.com/watch?v=Tof5pRedskI). You might also want to have a look at the following two-part guide for audio-developers ([1](https://www.youtube.com/watch?v=Q0vrQFyAdWI) and [2](https://www.youtube.com/watch?v=PoZAo2Vikbo)).
