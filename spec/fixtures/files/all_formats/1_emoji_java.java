/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package pack1;

/**
 *
 * @author damith
 */
public class DB_Connection {

    String Connection_String = "";
    String ip_address = "localhost"; //localhost 😉  🎉  🏋 🙌 😃 😆
    int port = 3306;
    String database_name = "jetwing_loyalty_platform";
    String username = "root"; //atslweb 😉  🎉  🏋 🙌 😃 😆
    String password = "123"; //atsl@Jet#2014! 😉  🎉  🏋 🙌 😃 😆 


    public String getConnection() {
        Connection_String = "jdbc:mysql://" + ip_address + ":" + port + "/" + database_name;
        return Connection_String;
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }
}
