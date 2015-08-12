/**
 * @author Chidchanok Choksuchat
 */
 /**
* Generate Bits and ID program ---CBM ------
* 
*@Input HDT program
*@Output
*@ 1. Bits file
*@ 2. ID file
*@ [Optional] MapBits-ID file
*/
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import org.rdfhdt.hdt.hdt.HDT;
import org.rdfhdt.hdt.hdt.HDTManager;
import org.rdfhdt.hdt.triples.IteratorTripleID;
import org.rdfhdt.hdt.triples.TripleID;
import org.rdfhdt.hdt.exceptions.NotFoundException;

public class CBM{

    public static void main(String args[])
            throws IOException, NullPointerException,
            ArrayIndexOutOfBoundsException, NotFoundException,FileNotFoundException {
        

        FileWriter tbstream = new FileWriter("ID_bits_InputStream");
        BufferedWriter outSingletb = new BufferedWriter(tbstream);
        FileWriter bstream = new FileWriter("bits_InputStream");
        BufferedWriter outSingleb = new BufferedWriter(bstream);
        FileWriter tstream = new FileWriter("ID_InputStream");
        BufferedWriter outSinglet = new BufferedWriter(tstream);

        ////////////////////////////////
		// initialize the memory
        ////////////////////////////////
        HDT hdt1 = HDTManager.mapHDT("//data//HDT", null);
        IteratorTripleID it1 = hdt1.getTriples().searchAll();
        //System.out.println("Estimated number of results: " + it1.estimatedNumResults() + "(" + it1.estimatedNumResults() * 3 + ")");

		////////////////////////////////
		//Set params
		////////////////////////////////
		int numElements = (int) (long) (it1.estimatedNumResults() * 3);

        int h_idata[] = new int[numElements];
        int h_sdata[] = new int[numElements];
        int h_pdata[] = new int[numElements];
        int h_bdata[] = new int[numElements];
        int h_predata[] = new int[numElements];

        int flagS[] = new int[numElements];
        int s = 0;

        int flagP[] = new int[numElements];
        int p = 0;

        int flagB[] = new int[numElements];
        int b = 0;
        int countTRIPLES = 0;
        int countTERM = 0;
        int countS = 0, countP = 0, countB = 0, countpre = 0;

		////////////////////////////////
		//Get Subject
		////////////////////////////////
		StringBuilder sb = new StringBuilder();

        TripleID ts1 = null;
        while (it1.hasNext()) {
            ts1 = it1.next();
            sb.append(ts1.getSubject()).append(" ");
            h_idata[countTERM] = ts1.getSubject();

       ////////////////////////////////
	   //Set Subject
	   ////////////////////////////////
            for (s = 0; s < numElements; s++) {
                if (s % 3 == 0) {
                    flagS[s] = 1;
                    h_sdata[countS] = ts1.getSubject();
                } else {
                    flagS[s] = 0;
                }
            }
            if ((countS >= 1)) {
                if (h_sdata[countS] == h_sdata[countS - 1]) {
                    h_predata[countpre] = h_sdata[countS - 1];
                } else if (h_sdata[countS] != h_sdata[countS - 1]) {
                    h_predata[countpre] = h_sdata[countS];

                    outSingletb.write("1 "+h_predata[countpre]+"\n"); 
					outSingletb.flush();
                    outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                    outSingleb.write("1");outSingleb.flush();
                    countpre++;                    
                }
            } else if (countS == 0) {
                h_predata[countpre] = h_sdata[countS];
                 outSingletb.write("1 " +h_predata[countpre]+"\n");
				 outSingletb.flush();
                 outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                 outSingleb.write("1");outSingleb.flush();
                countpre++;                
            }
            //////////////////////////////////////////////////
            countS++;
            countTERM++;
          
            //
            sb.append(ts1.getPredicate()).append(" ");
            h_idata[countTERM] = ts1.getPredicate();
            //////////////////////////////////////////////////
            for (p = 0; p < numElements; p++) {
                if (p % 3 == 1) {
                    flagP[p] = 1;
                    h_pdata[countP] = ts1.getPredicate();
                } else {
                    flagP[p] = 0;
                }
            }
            if ((countP == 0)) {
                h_predata[countpre] = h_pdata[countP];
                 outSingletb.write("1 " + h_predata[countpre]+"\n");
			outSingletb.flush();
                 outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                 outSingleb.write("1");outSingleb.flush();
                countpre++;
            } else if ((countP >= 1)) {
                if (h_pdata[countP] == h_pdata[countP - 1]) {
                    h_predata[countpre] = h_pdata[countP-1];
                }
                else if (h_pdata[countP] != h_pdata[countP - 1]) {
                    h_predata[countpre] = h_pdata[countP];
                     outSingletb.write("1 " +h_predata[countpre]+"\n");
			outSingletb.flush();
                     outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                     outSingleb.write("1");outSingleb.flush();
                    countpre++;
            }
}
            //////////////////////////////////////////////////
            countP++;
            countTERM++;
            //
            sb.append(ts1.getObject()).append(" ");
            h_idata[countTERM] = ts1.getObject();
            //////////////////////////////////////////////////
            for (b = 0; b < numElements; b++) {
                if (b % 3 == 2) {
                    flagB[b] = 1;
                    h_bdata[countB] = ts1.getObject();
                } else {
                    flagB[b] = 0;
                }
            }
            if ((countB == 0)) {
                h_predata[countpre] = h_bdata[countB];
                 outSingletb.write("0 " +h_predata[countpre]+"\n");outSingletb.flush();
                 outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                 outSingleb.write("0");outSingleb.flush();
                countpre++;
            }
             else if ((countB >= 1)) {
                if (h_bdata[countB] == h_bdata[countB - 1]) {
                    h_predata[countpre] = h_bdata[countB - 1];countpre++;
                     outSingletb.write("0 " + h_predata[countpre]+"\n");outSingletb.flush();
                     outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                     outSingleb.write("0");outSingleb.flush();
                }
                else if (h_bdata[countB] != h_bdata[countB - 1]) {
                    h_predata[countpre] = h_bdata[countB];
                     outSingletb.write("0 "+h_predata[countpre]+"\n");outSingletb.flush();
                     outSinglet.write(h_predata[countpre]+" ");outSinglet.flush();
                     outSingleb.write("0");outSingleb.flush();
                    countpre++;
                }
        }
        countB++;
        countTERM++;
        countTRIPLES++;
    }
outSingletb.close();
outSinglet.close();
outSingleb.close();
}
}