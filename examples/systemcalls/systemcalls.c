#include "systemcalls.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <fcntl.h>
#include <sys/wait.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{
/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/

    int result = system(cmd); // Execute the command

    if (result == 0) {
        // Command executed successfully
        return true;
    } else {
        // Command execution failed
        return false;
    }
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/


/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    va_end(args);
    command[count] = NULL;
    
    pid_t pid = fork();

    if (pid < 0)
    {
        // Fork failed
        perror("Fork failed");
        return false;
    }
    else if (pid == 0)
    {
        // Child process
        execv(command[0], command);
        // execv() returns only on error
        perror("Execv failed");
        exit(EXIT_FAILURE);
    }
    else
    {
        // Parent process
        int status;
        if (waitpid(pid, &status, 0) == -1)
        {
            // Error while waiting for child
            perror("Waitpid command fail!");
            return false;
        }
        if (WIFEXITED(status))
        {
            // Child process exited normally
            if (WEXITSTATUS(status) == 0)
            {
                // Child process exited successfully
                return true;
            }
        }
        // should not reach here. Child process did not exit normally or error
        return false;
    }

    return true;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    va_end(args);
    
    /*
     * TODO
    *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
    *   redirect standard out to a file specified by outputfile.
    *   The rest of the behaviour is same as do_exec()
    *
    */

    command[count] = NULL;

    va_end(args);

    int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1)
    {
        perror("Failed to open output file");
        return false;
    }

    pid_t pid = fork();

    if (pid < 0)
    {
        // Fork failed
        perror("Fork failed");
        close(fd);
        return false;
    }
    else if (pid == 0)
    {
        // Child process
        // Redirect standard output to the file descriptor
        if (dup2(fd, STDOUT_FILENO) == -1)
        {
            perror("dup2 failed");
            close(fd);
            exit(EXIT_FAILURE);
        }
        close(fd); // Close the original file descriptor
        execv(command[0], command);
        // execv() returns only on error
        perror("Execv failed");
        exit(EXIT_FAILURE);
    }
    else
    {
        // Parent process
        int status;
        if (waitpid(pid, &status, 0) == -1)
        {
            // Error in waiting for child process
            perror("Waitpid failed");
            close(fd);
            return false;
        }
        if (WIFEXITED(status))
        {
            // Child process exited normally
            if (WEXITSTATUS(status) == 0)
            {
                // Child process exited successfully
                close(fd);
                return true;
            }
        }
        // Child process did not exit normally or exited with an error
        close(fd);
        return false;
    }

    return true;
}
