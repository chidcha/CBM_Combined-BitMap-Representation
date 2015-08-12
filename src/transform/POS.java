
/**
 * @author Chidchanok Choksuchat
 */
import com.hp.hpl.jena.tdb.TDB;
import java.io.*;

public class POS {

    public static String REORDER_LINE = "";
    public static Writer outputSPO = null;
    public static Writer outputOPS = null;
    public static Writer outputPSO = null;
    public static Writer outputPOS = null;
    public static Writer dictSO = null;
    public static Writer dictS = null;
    public static Writer dictP = null;
    public static Writer dictO = null;
 

    public static void main(String... args) throws IOException, NullPointerException {
        // This also works for default union graph ....
        TDB.getContext().setTrue(TDB.symUnionDefaultGraph);
        BufferedReader readbuffer = null;
        String strRead;
        int a = 0;
        String filename = null;
        File filter_paths = new File("Compress_Path");
        String[] children = filter_paths.list();
        if (children == null) {
            System.out.println("does not exist or is not a directory");
        } else {
            for (a = 0; a < children.length; a++) {
                filename = children[a];

                readbuffer = new BufferedReader(new FileReader("NTripleInput"));

                try {

                    outputPOS = new BufferedWriter(new FileWriter("NTriplePOSOutput"));


                    while ((strRead = readbuffer.readLine()) != null) {
                        String splitarray[] = strRead.split(" ");
                        String firstentry = splitarray[0];
                        String secondentry = splitarray[1];
                        String third = "";
                        if (!splitarray[2].endsWith("\"\n")) {
                            for (int i = 3; i < (splitarray.length); i++) {
                                splitarray[2] = splitarray[2] + " " + splitarray[i];
                            }
                        }
                        third = splitarray[2];

                       ////////////////////////////////////////////////////////////////////////////////////
					   //Check by writting them out!
					   ////////////////////////////////////////////////////////////////////////////////////
                        outputPOS.write(secondentry + " " + third + " " + firstentry + "\n");

                    }

                    

                    outputPOS.close();

                    readbuffer.close();
                } catch (IOException ex) {
                    ex.printStackTrace();
                }

            }
        }

    }
}
