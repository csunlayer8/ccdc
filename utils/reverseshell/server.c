#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <arpa/inet.h>
#include <unistd.h>

#if defined(__linux__)
    #include <pty.h>
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
    #include <util.h>
    #include <sys/ioctl.h>
#endif

#include <poll.h>
#include <errno.h>
#include <termios.h>
#include <signal.h>

typedef struct sockaddr_in sockaddr_in;
typedef struct sockaddr sockaddr;
typedef struct pollfd pollfd;
typedef struct termios termios;
typedef struct winsize winsize;

volatile sig_atomic_t isResizeNeeded = false;

void handleSigWinch(int signal)
{
    isResizeNeeded = true;
}

void enableRawMode(termios *original)
{
    termios raw;
    if (tcgetattr(STDIN_FILENO, original) == -1)
    {
        perror("tcgetattr");
        exit(EXIT_FAILURE);
    }

    raw = *original;
    cfmakeraw(&raw);
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1)
    {
        perror("tcsetattr");
        exit(EXIT_FAILURE);
    }
}

void disableRawMode(termios *original)
{
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, original) == -1)
    {
        perror("tcsetattr");
        exit(EXIT_FAILURE);
    }
}

void sendWindowSize(int clientFD)
{
    winsize ws;
    uint8_t marker = 0xFF;
    if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == -1) return;
    write(clientFD, &marker, 1);
    write(clientFD, &ws, sizeof(ws));
}

void monitorFD(int clientFD)
{
    char buffer[4096];
    ssize_t bytesRead;
    pollfd fds[2];

    fds[0].fd = STDIN_FILENO;
    fds[0].events = POLLIN;

    fds[1].fd = clientFD;
    fds[1].events = POLLIN;

    sendWindowSize(clientFD);

    while (true)
    {
        if (poll(fds, 2, -1) < 0)
        {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }

        if (isResizeNeeded)
        {
            isResizeNeeded = false;
            sendWindowSize(clientFD);
        }

        if (fds[0].revents & (POLLIN | POLLHUP))
        {
            bytesRead = read(STDIN_FILENO, buffer, sizeof(buffer));
            if (bytesRead <= 0) break;
            if (write(clientFD, buffer, (size_t)bytesRead) < 0) break;
        }

        if (fds[1].revents & (POLLIN | POLLHUP))
        {
            bytesRead = read(clientFD, buffer, sizeof(buffer));
            if (bytesRead <= 0) break;
            if (write(STDIN_FILENO, buffer, (size_t)bytesRead) < 0) break;
        }
        if (fds[0].revents & (POLLERR | POLLNVAL)) break;
        if (fds[1].revents & (POLLERR | POLLNVAL)) break;
    }
}

void listenToClient(void)
{
    int clientFD, serverFD;
    sockaddr_in sa;
    char buffer[4096];
    ssize_t bytesRead;
    pollfd fds[2];
    termios original;

    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = INADDR_ANY;
    sa.sin_port = htons(4444);

    serverFD = socket(AF_INET, SOCK_STREAM, 0);
    if (serverFD < 0)
    {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    if (bind(serverFD, (sockaddr*)&sa, sizeof(sa)) < 0)
    {
        perror("bind");
        exit(EXIT_FAILURE);
    }

    if (listen(serverFD, 1) < 0)
    {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    clientFD = accept(serverFD, NULL, NULL);
    if (clientFD < 0)
    {
        perror("accept");
        exit(EXIT_FAILURE);
    }

    signal(SIGWINCH, handleSigWinch);
    enableRawMode(&original);
    monitorFD(clientFD);
    disableRawMode(&original);
    close(clientFD);
    close(serverFD);
}

int main(void)
{
    listenToClient();
    return 0;
}
